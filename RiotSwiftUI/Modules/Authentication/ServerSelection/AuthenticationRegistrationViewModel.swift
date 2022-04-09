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

import SwiftUI
import Combine

@available(iOS 14, *)
typealias AuthenticationRegistrationViewModelType = StateStoreViewModel<AuthenticationRegistrationViewState,
                                                                 Never,
                                                                 AuthenticationRegistrationViewAction>


@available(iOS 14, *)
@MainActor class AuthenticationRegistrationViewModel: AuthenticationRegistrationViewModelType, AuthenticationRegistrationViewModelProtocol {

    // MARK: - Properties

    // MARK: Private
    
    let authenticationService: AuthenticationService
    let registrationWizard: RegistrationWizard
    private var currentTask: Task<Void, Error>?

    // MARK: Public

    var completion: ((AuthenticationRegistrationViewModelResult) -> Void)?

    // MARK: - Setup

    init(authenticationService: AuthenticationService, registrationResult: RegistrationResult, loginFlowResult: LoginFlowResult) {
        let viewState: AuthenticationRegistrationViewState
        
        do {
            self.authenticationService = authenticationService
            self.registrationWizard = try authenticationService.registrationWizard()
            viewState = AuthenticationRegistrationViewState(homeserverString: registrationWizard.pendingData.homeserverString,
                                                            ssoIdentityProviders: loginFlowResult.ssoIdentityProviders,
                                                            bindings: AuthenticationRegistrationBindings())
        } catch {
            fatalError("Failed to get the registration wizard: \(error.localizedDescription)")
        }
        
        super.init(initialViewState: viewState)
    }
    
    // MARK: - Public

    override func process(viewAction: AuthenticationRegistrationViewAction) {
        Task {
            await MainActor.run {
                switch viewAction {
                case .selectServer:
                    completion?(.selectServer)
                case .next:
                    register()
                }
            }
        }
    }
    
    // MARK: - Private
    
    private func register() {
        // reAuthHelper.data = state.password
        let username = state.bindings.username
        let password = state.bindings.password
        let deviceDisplayName = UIDevice.current.isPhone ? VectorL10n.loginMobileDevice : VectorL10n.loginTabletDevice
        
        currentTask = executeRegistrationStep(withLoading: true) { wizard in
            try await wizard.createAccount(username: username, password: password, initialDeviceDisplayName: deviceDisplayName)
        }
    }
}

@available(iOS 14, *)
extension AuthenticationRegistrationViewModel: FlowStepHandling { }
