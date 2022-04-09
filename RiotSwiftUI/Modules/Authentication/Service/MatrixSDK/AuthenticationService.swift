// 
// Copyright 2021 New Vector Ltd
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
import Combine

@available(iOS 14.0, *)
protocol AuthenticationServiceDelegate: AnyObject {
    func authenticationServiceDidUpdateRegistrationParameters(_ authenticationService: AuthenticationService)
}

enum AuthenticationError: Error {
    case encodingError
    case decodingError
    case invalidHomeserver
    case loginFlowNotCalled
    case missingRegistrationWizard
}

@available(iOS 14.0, *)
class AuthenticationService: NSObject {
    
    static let shared = AuthenticationService()
    
    // MARK: - Properties
    
    // MARK: Private
    
    private var client: MXRestClient
    private var pendingData: AuthenticationPendingData?
    private var currentRegistrationWizard: RegistrationWizard?
    private var currentLoginWizard: LoginWizard?
    private var sessionCreator = SessionCreator()
    
    // MARK: Public
    
    weak var delegate: AuthenticationServiceDelegate?
    
    // MARK: - Setup
    
    override init() {
        guard let homeserverURL = URL(string: BuildSettings.serverConfigDefaultHomeserverUrlString) else {
            fatalError("[AuthenticationService]: Failed to create URL from default homeserver URL string.")
        }
        
        client = MXRestClient(homeServer: homeserverURL, unrecognizedCertificateHandler: nil)
        
        super.init()
    }
    
    /// Check if authentication is needed by checking for any accounts.
    /// - Returns: `true` there are no accounts or if there is an inactive account that has had a soft logout.
    var needsAuthentication: Bool {
        MXKAccountManager.shared().accounts.isEmpty || softLogoutCredentials != nil
    }
    
    var softLogoutCredentials: MXCredentials? {
        guard MXKAccountManager.shared().activeAccounts.isEmpty else { return nil }
        for account in MXKAccountManager.shared().accounts {
            if account.isSoftLogout {
                return account.mxCredentials
            }
        }
        
        return nil
    }
    
    /// Get the last authenticated [Session], if there is an active session.
    /// - Returns: The last active session if any, or `nil`
    var lastAuthenticatedSession: MXSession? {
        MXKAccountManager.shared().activeAccounts?.first?.mxSession
    }
    
    enum AuthenticationMode {
        case login
        case registration
    }
    
    /// Request the supported login flows for this homeserver.
    /// This is the first method to call to be able to get a wizard to login or to create an account
    /// - Parameter homeserverString: The homeserver string entered by the user.
    func loginFlow(for homeserverString: String) async throws -> LoginFlowResult {
        pendingData = nil
        
        var homeserverString = homeserverString
        
        #warning("Lets do this elsewhere")
        if !homeserverString.contains("://") {
            homeserverString = "https://\(homeserverString)"
        }
        
        guard let baseURL = URL(string: homeserverString) else {
            throw AuthenticationError.invalidHomeserver
        }
        
        client = MXRestClient(homeServer: baseURL, unrecognizedCertificateHandler: nil)
        pendingData = AuthenticationPendingData(homeserverString: homeserverString)
        
        return try await getLoginFlowResult(client: client)
    }
    
    /// Request the supported login flows for the corresponding session.
    /// This method is used to get the flows for a server after a soft-logout.
    /// - Parameter session: The MXSession where a soft-logout has occurred.
    func loginFlow(for session: MXSession) async throws -> LoginFlowResult {
        pendingData = nil
        
        client = session.matrixRestClient
        pendingData = AuthenticationPendingData(homeserverString: client.homeserver)
        
        return try await getLoginFlowResult(client: session.matrixRestClient)
    }
    
//    /// Get a SSO url
//    func getSSOURL(redirectUrl: String, deviceId: String?, providerId: String?) -> String? {
//        
//    }
    
    /// Get the sign in or sign up fallback URL
    func fallbackURL(for authenticationMode: AuthenticationMode) -> URL {
        switch authenticationMode {
        case .login:
            return client.loginFallbackURL
        case .registration:
            return client.registerFallbackURL
        }
    }
    
    /// Return a LoginWizard, to login to the homeserver. The login flow has to be retrieved first.
    ///
    /// See ``LoginWizard`` for more details
    func loginWizard() throws -> LoginWizard {
        if let currentLoginWizard = currentLoginWizard {
            return currentLoginWizard
        }
        
        guard let pendingData = pendingData else {
            throw AuthenticationError.loginFlowNotCalled
        }
        
        let wizard = LoginWizard()
        return wizard
    }
    
    /// Return a RegistrationWizard, to create a matrix account on the homeserver. The login flow has to be retrieved first.
    ///
    /// See ``RegistrationWizard`` for more details.
    func registrationWizard() throws -> RegistrationWizard {
        if let currentRegistrationWizard = currentRegistrationWizard {
            return currentRegistrationWizard
        }
        
        guard let pendingData = pendingData else {
            throw AuthenticationError.loginFlowNotCalled
        }

        
        let wizard = RegistrationWizard(client: client, pendingData: pendingData)
        currentRegistrationWizard = wizard
        return wizard
    }
    
    /// True when login and password has been sent with success to the homeserver
    var isRegistrationStarted: Bool {
        currentRegistrationWizard?.isRegistrationStarted ?? false
    }
    
    /// Cancel pending login or pending registration
    func cancelPendingLoginOrRegistration() {
        currentLoginWizard = nil
        currentRegistrationWizard = nil

        // Keep only the home sever config
        guard let pendingData = pendingData else {
            // Should not happen
            return
        }

        self.pendingData = AuthenticationPendingData(homeserverString: pendingData.homeserverString)
    }
    
    /// Reset all pending settings, including current HomeServerConnectionConfig
    func reset() async {
        pendingData = nil
        currentRegistrationWizard = nil
        currentLoginWizard = nil
    }

    /// Create a session after a SSO successful login
    func makeSessionFromSSO(credentials: MXCredentials) -> MXSession {
        sessionCreator.createSession(credentials: credentials, client: client)
    }
    
//    /// Perform a well-known request, using the domain from the matrixId
//    func getWellKnownData(matrixId: String,
//                          homeServerConnectionConfig: HomeServerConnectionConfig?) async -> WellknownResult {
//        
//    }
//
//    /// Authenticate with a matrixId and a password
//    /// Usually call this after a successful call to getWellKnownData()
//    /// - Parameter homeServerConnectionConfig the information about the homeserver and other configuration
//    /// - Parameter matrixId the matrixId of the user
//    /// - Parameter password the password of the account
//    /// - Parameter initialDeviceName the initial device name
//    /// - Parameter deviceId the device id, optional. If not provided or null, the server will generate one.
//    func directAuthentication(homeServerConnectionConfig: HomeServerConnectionConfig,
//                              matrixId: String,
//                              password: String,
//                              initialDeviceName: String,
//                              deviceId: String? = nil) async -> MXSession {
//        
//    }
    
    // MARK: - Private
    
    private func getLoginFlowResult(client: MXRestClient/*, versions: Versions*/) async throws -> LoginFlowResult {
        // Get the login flow
        let loginFlowResponse = try await client.getLoginSession()
        
        let identityProviders = loginFlowResponse.flows?.compactMap { $0 as? MXLoginSSOFlow }.first?.identityProviders ?? []
        return LoginFlowResult(supportedLoginTypes: loginFlowResponse.flows?.compactMap { $0 } ?? [],
                               ssoIdentityProviders: identityProviders.sorted { $0.name < $1.name }.map { $0.ssoIdentityProvider },
                               homeserverURL: client.homeserver)
    }
}

extension MXLoginSSOIdentityProvider {
    var ssoIdentityProvider: SSOIdentityProvider {
        SSOIdentityProvider(id: identifier, name: name, brand: brand, iconURL: icon)
    }
}
