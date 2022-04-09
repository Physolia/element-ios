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
import CommonKit

@available(iOS 14.0, *)
struct AuthenticationRegistrationCoordinatorParameters {
    let authenticationService: AuthenticationService
    /// The registration flows that are to be displayed.
    let registrationResult: RegistrationResult
    /// The login flows to allow for SSO sign up.
    let loginFlowResult: LoginFlowResult
}

enum AuthenticationRegistrationCoordinatorResult {
    case selectServer
    case flowResponse(FlowResult)
    case sessionCreated(session: MXSession, isAccountCreated: Bool)
}

@available(iOS 14.0, *)
@MainActor final class AuthenticationRegistrationCoordinator: Coordinator, Presentable {
    
    // MARK: - Properties
    
    // MARK: Private
    
    private let parameters: AuthenticationRegistrationCoordinatorParameters
    private let authenticationRegistrationHostingController: VectorHostingController
    private var authenticationRegistrationViewModel: AuthenticationRegistrationViewModelProtocol
    
    private var indicatorPresenter: UserIndicatorTypePresenterProtocol
    private var waitingIndicator: UserIndicator?
    
    // MARK: Public

    // Must be used only internally
    var childCoordinators: [Coordinator] = []
    var completion: ((AuthenticationRegistrationCoordinatorResult) -> Void)?
    
    // MARK: - Setup
    
    init(parameters: AuthenticationRegistrationCoordinatorParameters) {
        self.parameters = parameters
        
        let viewModel = AuthenticationRegistrationViewModel(authenticationService: parameters.authenticationService,
                                                            registrationResult: parameters.registrationResult,
                                                            loginFlowResult: parameters.loginFlowResult)
        authenticationRegistrationViewModel = viewModel
        
        let view = AuthenticationRegistrationScreen(viewModel: viewModel.context)
        authenticationRegistrationHostingController = VectorHostingController(rootView: view)
        authenticationRegistrationHostingController.vc_removeBackTitle()
        authenticationRegistrationHostingController.enableNavigationBarScrollEdgeAppearance = true
        
        indicatorPresenter = UserIndicatorTypePresenter(presentingViewController: authenticationRegistrationHostingController)
    }
    
    // MARK: - Public
    func start() {
        MXLog.debug("[AuthenticationRegistrationCoordinator] did start.")
        authenticationRegistrationViewModel.completion = { [weak self] result in
            guard let self = self else { return }
            MXLog.debug("[AuthenticationRegistrationCoordinator] AuthenticationRegistrationViewModel did complete with result: \(result).")
            switch result {
            case .selectServer:
                self.completion?(.selectServer)
            case .startLoading:
                self.startLoading()
            case .stopLoading:
                self.stopLoading()
            case .flowResponse(flowResult: let flowResult):
                self.completion?(.flowResponse(flowResult))
            case .sessionCreated(session: let session, isAccountCreated: let isAccountCreated):
                self.completion?(.sessionCreated(session: session, isAccountCreated: isAccountCreated))
            }
        }
    }
    
    func toPresentable() -> UIViewController {
        return self.authenticationRegistrationHostingController
    }
    
    // MARK: - Private
    
    /// Show a blocking activity indicator whilst saving.
    private func startLoading(label: String? = nil) {
        waitingIndicator = indicatorPresenter.present(.loading(label: label ?? VectorL10n.loading, isInteractionBlocking: true))
    }
    
    /// Hide the currently displayed activity indicator.
    private func stopLoading() {
        waitingIndicator = nil
    }
}
