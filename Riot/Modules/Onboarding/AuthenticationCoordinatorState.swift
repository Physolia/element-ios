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
import MatrixSDK

@available(iOS 14.0, *)
struct AuthenticationCoordinatorState {
//    var asyncLoginAction: Task<Void, Error>?
//    var asyncHomeServerLoginFlowRequest: Task<Void, Error>?
//    var asyncResetPassword: Task<Void, Error>?
//    var asyncResetMailConfirmed: Task<Void, Error>?
//    var asyncRegistration: Task<Void, Error>?
    
    // User choices
//    var serverType: ServerType = .unknown
//    var signMode: SignMode = .unknown
    var resetPasswordEmail: String?
    var homeserverStringFromUser: String?
    
    /// Can be modified after a Wellknown request
    var homeserverString: String?
    
    /// For SSO session recovery
    var deviceId: String?
    
    // Network result
    var loginMode: LoginMode = .unknown
    /// Supported types for the login. We cannot use a sealed class for LoginType because it is not serializable
    var loginModeSupportedTypes = [MXLoginFlow]()
    var knownCustomHomeServersUrls = [String]()
    var isForceLoginFallbackEnabled = false
    
//    var isLoading: Bool {
//        return asyncLoginAction is Loading ||
//        asyncHomeServerLoginFlowRequest is Loading ||
//        asyncResetPassword is Loading ||
//        asyncResetMailConfirmed is Loading ||
//        asyncRegistration is Loading
//    }
    
//    var isAuthTaskCompleted: Bool {
//        guard let result = asyncLoginAction?.result else { return false }
//        return result == .success
//    }
}
