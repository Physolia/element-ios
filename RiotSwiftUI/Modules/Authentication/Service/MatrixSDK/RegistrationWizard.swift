//
// Copyright 2022 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

@available(iOS 14.0, *)
/// Set of methods to be able to create an account on a homeserver.
///
/// Common scenario to register an account successfully:
///  - Call `registrationFlow` to check that you application supports all the mandatory registration stages
///  - Call `createAccount` to start the account creation
///  - Fulfil all mandatory stages using the methods `performReCaptcha` `acceptTerms` `dummy`, etc.
///
/// More documentation can be found in the file https://github.com/vector-im/element-android/blob/main/docs/signup.md
/// and https://matrix.org/docs/spec/client_server/latest#account-registration-and-management
class RegistrationWizard {
    
    enum WizardError: Error {
        case createAccountNotCalled
        case noPendingThreePID
        case missingThreePIDURL
        case threePIDValidationFailure
        case httpClientFailure
    }
    
    let client: MXRestClient
    let sessionCreator: SessionCreator
    let pendingData: AuthenticationPendingData
    
    /// This is the current ThreePID, waiting for validation. The SDK will store it in database, so it can be
    /// restored even if the app has been killed during the registration
    var currentThreePID: String? {
        guard let threePid = pendingData.currentThreePIDData?.threePID else { return nil }
        
        switch threePid {
        case .email(let string):
            return string
        case .msisdn(let msisdn, _):
            return pendingData.currentThreePIDData?.registrationResponse.formattedMSISDN ?? msisdn
        }
    }

    /// True when login and password have been sent with success to the homeserver,
    /// i.e. `createAccount` has been called successfully.
    var isRegistrationStarted: Bool {
        pendingData.isRegistrationStarted
    }
    
    init(client: MXRestClient, sessionCreator: SessionCreator = SessionCreator(), pendingData: AuthenticationPendingData) {
        self.client = client
        self.sessionCreator = sessionCreator
        self.pendingData = pendingData
    }
    
    /// Call this method to get the possible registration flow of the current homeserver.
    /// It can be useful to ensure that your application implementation supports all the stages
    /// required to create an account. If it is not the case, you will have to use the web fallback
    /// to let the user create an account with your application.
    /// See `AuthenticationService.getFallbackUrl`
    func registrationFlow() async throws -> RegistrationResult {
        let parameters = RegistrationParameters()
        return try await performRegistrationRequest(parameters: parameters)
    }

    /// Can be call to check is the desired username is available for registration on the current homeserver.
    /// It may also fails if the desired username is not correctly formatted or does not follow any restriction on
    /// the homeserver. Ex: username with only digits may be rejected.
    /// - Parameter username the desired username. Ex: "alice"
    func registrationAvailable(username: String) async throws -> Bool {
        try await client.isUsernameAvailable(username)
    }

    /// This is the first method to call in order to create an account and start the registration process.
    ///
    /// - Parameter username the desired username. Ex: "alice"
    /// - Parameter password the desired password
    /// - Parameter initialDeviceDisplayName the device display name
    func createAccount(username: String?,
                       password: String?,
                       initialDeviceDisplayName: String?) async throws -> RegistrationResult {
        let parameters = RegistrationParameters(username: username, password: password, initialDeviceDisplayName: initialDeviceDisplayName)
        let result = try await performRegistrationRequest(parameters: parameters)
        pendingData.isRegistrationStarted = true
        return result
    }

    /// Perform the "m.login.recaptcha" stage.
    ///
    /// - Parameter response: The response from ReCaptcha
    func performReCaptcha(response: String) async throws -> RegistrationResult {
        guard let session = pendingData.currentSession else {
            throw WizardError.createAccountNotCalled
        }
        
        let parameters = RegistrationParameters(auth: AuthenticationParameters.captchaParameters(session: session, captchaResponse: response))
        return try await performRegistrationRequest(parameters: parameters)
    }

    /// Perform the "m.login.terms" stage.
    func acceptTerms() async throws -> RegistrationResult {
        guard let session = pendingData.currentSession else {
            throw WizardError.createAccountNotCalled
        }
        
        let parameters = RegistrationParameters(auth: AuthenticationParameters(type: kMXLoginFlowTypeTerms, session: session))
        return try await performRegistrationRequest(parameters: parameters)
    }

    /// Perform the "m.login.dummy" stage.
    func dummy() async throws -> RegistrationResult {
        guard let session = pendingData.currentSession else {
            throw WizardError.createAccountNotCalled
        }
        
        let parameters = RegistrationParameters(auth: AuthenticationParameters(type: kMXLoginFlowTypeDummy, session: session))
        return try await performRegistrationRequest(parameters: parameters)
    }

    /// Perform the "m.login.email.identity" or "m.login.msisdn" stage.
    ///
    /// - Parameter threePID the threePID to add to the account. If this is an email, the homeserver will send an email
    /// to validate it. For a msisdn a SMS will be sent.
    func addThreePID(threePID: RegisterThreePID) async throws -> RegistrationResult {
        pendingData.currentThreePIDData = nil
        return try await sendThreePID(threePID: threePID)
    }

    /// Ask the homeserver to send again the current threePID (email or msisdn).
    func sendAgainThreePID() async throws -> RegistrationResult {
        guard let threePID = pendingData.currentThreePIDData?.threePID else {
            throw WizardError.createAccountNotCalled
        }
        return try await sendThreePID(threePID: threePID)
    }

    /// Send the code received by SMS to validate a msisdn.
    /// If the code is correct, the registration request will be executed to validate the msisdn.
    func handleValidateThreePID(code: String) async throws -> RegistrationResult {
        return try await validateThreePid(code: code)
    }

    /// Useful to poll the homeserver when waiting for the email to be validated by the user.
    /// Once the email is validated, this method will return successfully.
    /// - Parameter delay How long to wait before sending the request.
    func checkIfEmailHasBeenValidated(delay: TimeInterval) async throws -> RegistrationResult {
        guard let parameters = pendingData.currentThreePIDData?.registrationParameters else {
            throw WizardError.noPendingThreePID
        }

        return try await performRegistrationRequest(parameters: parameters, delay: delay)
    }
    
    // MARK: - Private
    
    private func validateThreePid(code: String) async throws -> RegistrationResult {
        guard let threePIDData = pendingData.currentThreePIDData else {
            throw WizardError.noPendingThreePID
        }
        
        guard let url = threePIDData.registrationResponse.submitURL else {
            throw WizardError.missingThreePIDURL
        }
        
        
        let validationBody = ThreePIDValidationCodeBody(clientSecret: pendingData.clientSecret,
                                                        sessionID: threePIDData.registrationResponse.sessionID,
                                                        code: code)
        let validationDictionary = try validationBody.dictionary()
        
        #warning("Seems odd to pass a nil baseURL and then the url as the path, yet this is how MXK3PID works")
        guard let httpClient = MXHTTPClient(baseURL: nil, andOnUnrecognizedCertificateBlock: nil) else {
            throw WizardError.httpClientFailure
        }
        let responseDictionary = try await httpClient.request(withMethod: "POST", path: url, parameters: validationDictionary)
        
        // Response is a json dictionary with a single success parameter
        if responseDictionary["success"] as? Bool == true {
            // The entered code is correct
            // Same than validate email
            let parameters = threePIDData.registrationParameters
            return try await performRegistrationRequest(parameters: parameters, delay: 3)
        } else {
            // The code is not correct
            throw WizardError.threePIDValidationFailure
        }
    }
    
    private func sendThreePID(threePID: RegisterThreePID) async throws -> RegistrationResult {
        guard let session = pendingData.currentSession else {
            throw WizardError.createAccountNotCalled
        }
        
        let response = try await client.requestTokenDuringRegistration(for: threePID,
                                                                       clientSecret: pendingData.clientSecret,
                                                                       sendAttempt: pendingData.sendAttempt)
        
        pendingData.sendAttempt += 1
        
        let threePIDCredentials = ThreePIDCredentials(clientSecret: pendingData.clientSecret, sessionID: response.sessionID)
        let authenticationParameters: AuthenticationParameters
        switch threePID {
        case .email:
            authenticationParameters = AuthenticationParameters.emailIdentityParameters(session: session, threePIDCredentials: threePIDCredentials)
        case .msisdn:
            authenticationParameters = AuthenticationParameters.msisdnIdentityParameters(session: session, threePIDCredentials: threePIDCredentials)
        }
        
        let parameters = RegistrationParameters(auth: authenticationParameters)
        
        pendingData.currentThreePIDData = ThreePIDData(threePID: threePID, registrationResponse: response, registrationParameters: parameters)

        // Send the session id for the first time
        return try await performRegistrationRequest(parameters: parameters)
    }
    
    private func performRegistrationRequest(parameters: RegistrationParameters,
                                            delay: TimeInterval = 0) async throws -> RegistrationResult {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        let jsonData = try JSONEncoder().encode(parameters)
        guard let dictionary = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw MXRestClient.ClientError.decodingError
        }
        
        do {
            let response = try await client.register(parameters: dictionary)
            let credentials = MXCredentials(loginResponse: response, andDefaultCredentials: client.credentials)
            return .success(sessionCreator.createSession(credentials: credentials, client: client))
        } catch {
            let nsError = error as NSError
            
            guard
                let jsonResponse = nsError.userInfo[MXHTTPClientErrorResponseDataKey] as? [String: Any],
                let authenticationSession = MXAuthenticationSession(fromJSON: jsonResponse)
            else { throw error }
            
            pendingData.currentSession = authenticationSession.session
            return .flowResponse(authenticationSession.flowResult)
        }
    }
}

struct AuthenticationParameters: Codable {
    /// The type of authentication taking place. The identifier from `MXLoginFlowType`.
    let type: String
    
    /// Note: session can be null for reset password request
    var session: String?
    
    /// parameter for "m.login.recaptcha" type
    var captchaResponse: String?
    
    /// parameter for "m.login.email.identity" type
    var threePIDCredentials: ThreePIDCredentials?
    
    enum CodingKeys: String, CodingKey {
        case type
        case session
        case captchaResponse = "response"
        case threePIDCredentials = "threepid_creds"
    }
    
    static func captchaParameters(session: String, captchaResponse: String) -> AuthenticationParameters {
        AuthenticationParameters(type: kMXLoginFlowTypeRecaptcha, session: session, captchaResponse: captchaResponse)
    }
    
    static func emailIdentityParameters(session: String, threePIDCredentials: ThreePIDCredentials) -> AuthenticationParameters {
        AuthenticationParameters(type: kMXLoginFlowTypeEmailIdentity, session: session, threePIDCredentials: threePIDCredentials)
    }
    
    // Note that there is a bug in Synapse (needs investigation), but if we pass .msisdn,
    // the homeserver answer with the login flow with MatrixError fields and not with a simple MatrixError 401.
    static func msisdnIdentityParameters(session: String, threePIDCredentials: ThreePIDCredentials) -> AuthenticationParameters {
        AuthenticationParameters(type: kMXLoginFlowTypeMSISDN, session: session, threePIDCredentials: threePIDCredentials)
    }
    
    static func resetPasswordParameters(clientSecret: String, sessionID: String) -> AuthenticationParameters {
        AuthenticationParameters(type: kMXLoginFlowTypeEmailIdentity,
                                 session: nil,
                                 threePIDCredentials: ThreePIDCredentials(clientSecret: clientSecret, sessionID: sessionID))
    }
}

struct RegistrationParameters: Codable {
    /// Authentication parameters
    var auth: AuthenticationParameters?
    
    /// The account username
    var username: String?
    
    /// The account password
    var password: String?
    
    /// Device name
    var initialDeviceDisplayName: String?
    
    /// Temporary flag to notify the server that we support msisdn flow. Used to prevent old app
    /// versions to end up in fallback because the HS returns the msisdn flow which they don't support
    var xShowMsisdn: Bool?
    
    enum CodingKeys: String, CodingKey {
        case auth
        case username
        case password
        case initialDeviceDisplayName = "initial_device_display_name"
        case xShowMsisdn = "x_show_msisdn"
    }
    
    func dictionary() throws -> [String: Any] {
        let jsonData = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AuthenticationError.decodingError
        }
        return dictionary
    }
}

enum RegistrationResult {
    case success(MXSession)
    case flowResponse(FlowResult)
}

struct FlowResult {
    let missingStages: [Stage]
    let completedStages: [Stage]
    
    enum Stage {
        // m.login.recaptcha
        case reCaptcha(mandatory: Bool, publicKey: String)
        
        // m.login.email.identity
        case email(mandatory: Bool)
        
        // m.login.msisdn
        case msisdn(mandatory: Bool)
        
        // m.login.dummy, can be mandatory if there is no other stages. In this case the account cannot
        // be created by just sending a username and a password, the dummy stage has to be done
        case dummy(mandatory: Bool)
        
        // Undocumented yet: m.login.terms
        case terms(mandatory: Bool, policies: TermPolicies)
        
        // For unknown stages
        case other(mandatory: Bool, type: String, params: [AnyHashable: Any])
    }
}

extension MXAuthenticationSession {
    var flowResult: FlowResult {
        let allFlowTypes = Set(flows.flatMap { $0.stages ?? [] })
        var missingStages = [FlowResult.Stage]()
        var completedStages = [FlowResult.Stage]()
        
        allFlowTypes.forEach { flow in
            let isMandatory = flows.allSatisfy { $0.stages.contains(flow) }
            
            let stage: FlowResult.Stage
            switch flow {
            case kMXLoginFlowTypeRecaptcha:
                let parameters = params[flow] as? [AnyHashable: Any]
                let publicKey = parameters?["public_key"] as? String
                stage = .reCaptcha(mandatory: isMandatory, publicKey: publicKey ?? "")
            case kMXLoginFlowTypeDummy:
                stage = .dummy(mandatory: isMandatory)
            case kMXLoginFlowTypeTerms:
                let parameters = params[flow] as? [String: String]
                stage = .terms(mandatory: isMandatory, policies: parameters ?? [:])
            case kMXLoginFlowTypeMSISDN:
                stage = .msisdn(mandatory: isMandatory)
            case kMXLoginFlowTypeEmailIdentity:
                stage = .email(mandatory: isMandatory)
            default:
                let parameters = params[flow] as? [AnyHashable: Any]
                stage = .other(mandatory: isMandatory, type: flow, params: parameters ?? [:])
            }
            
            if let completed = completed, completed.contains(flow) {
                completedStages.append(stage)
            } else {
                missingStages.append(stage)
            }
        }
        
        return FlowResult(missingStages: missingStages, completedStages: completedStages)
    }
    
    func nextUncompletedStage(flowIndex: Int = 0) -> String? {
        guard flows.count < flowIndex else { return nil }
        return flows[flowIndex].stages.first {
            guard let completed = completed else { return false }
            return !completed.contains($0)
        }
    }
}

typealias TermPolicies = [String: String]
