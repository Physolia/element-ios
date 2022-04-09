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

// MARK: - Coordinator

enum AuthenticationRegistrationPresence {
    case online
    case idle
    case offline
}

extension AuthenticationRegistrationPresence: Identifiable, CaseIterable {
    var id: Self { self }
    
    var title: String {
        switch self {
        case .online:
            return VectorL10n.roomParticipantsOnline
        case .idle:
            return VectorL10n.roomParticipantsIdle
        case .offline:
            return VectorL10n.roomParticipantsOffline
        }
    }
}

// MARK: View model

enum AuthenticationRegistrationViewModelResult {
    case selectServer
    case startLoading
    case stopLoading
    case flowResponse(flowResult: FlowResult)
    case sessionCreated(session: MXSession, isAccountCreated: Bool)
}

// MARK: View

struct AuthenticationRegistrationViewState: BindableState {
    var homeserverString: String
    var ssoIdentityProviders: [SSOIdentityProvider]
    var bindings: AuthenticationRegistrationBindings
    
    var serverDescription: String? {
        guard homeserverString == "matrix.org" else { return nil }
        return VectorL10n.onboardingRegistrationMatrixDescription
    }
    
    var showRegistrationForm: Bool {
        true
    }
    
    var showSSOButtons: Bool {
        !ssoIdentityProviders.isEmpty
    }
}

struct AuthenticationRegistrationBindings: BindableState {
    var username = ""
    var password = ""
}

enum AuthenticationRegistrationViewAction {
    case selectServer
    case next
}

struct SSOIdentityProvider: Identifiable {
    /// The identifier field (id field in JSON) is the Identity Provider identifier used for the SSO Web page redirection `/login/sso/redirect/{idp_id}`.
    let id: String
    /// The name field is a human readable string intended to be printed by the client.
    let name: String
    /// The brand field is optional. It allows the client to style the login button to suit a particular brand.
    let brand: String?
    /// The icon field is an optional field that points to an icon representing the identity provider. If present then it must be an HTTPS URL to an image resource.
    let iconURL: String?
}
