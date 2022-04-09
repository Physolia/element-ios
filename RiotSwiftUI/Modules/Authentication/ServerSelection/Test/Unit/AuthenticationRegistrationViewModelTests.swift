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

import XCTest
import Combine

@testable import RiotSwiftUI

@available(iOS 14.0, *)
class AuthenticationRegistrationViewModelTests: XCTestCase {
    private enum Constants {
        static let presenceInitialValue: AuthenticationRegistrationPresence = .offline
        static let displayName = "Alice"
    }
    var service: MockAuthenticationService!
    var viewModel: AuthenticationRegistrationViewModelProtocol!
    var context: AuthenticationRegistrationViewModelType.Context!
    var cancellables = Set<AnyCancellable>()
    override func setUpWithError() throws {
        service = MockAuthenticationService(displayName: Constants.displayName, presence: Constants.presenceInitialValue)
        viewModel = AuthenticationRegistrationViewModel.makeAuthenticationRegistrationViewModel(authenticationService: service)
        context = viewModel.context
    }

    func testInitialState() {
        XCTAssertEqual(context.viewState.displayName, Constants.displayName)
        XCTAssertEqual(context.viewState.presence, Constants.presenceInitialValue)
    }

    func testFirstPresenceReceived() throws {
        let presencePublisher = context.$viewState.map(\.presence).removeDuplicates().collect(1).first()
        XCTAssertEqual(try xcAwait(presencePublisher), [Constants.presenceInitialValue])
    }

    func testPresenceUpdatesReceived() throws {
        let presencePublisher = context.$viewState.map(\.presence).removeDuplicates().collect(3).first()
        let awaitDeferred = xcAwaitDeferred(presencePublisher)
        let newPresenceValue1: AuthenticationRegistrationPresence = .online
        let newPresenceValue2: AuthenticationRegistrationPresence = .idle
        service.simulateUpdate(presence: newPresenceValue1)
        service.simulateUpdate(presence: newPresenceValue2)
        XCTAssertEqual(try awaitDeferred(), [Constants.presenceInitialValue, newPresenceValue1, newPresenceValue2])
    }
}
