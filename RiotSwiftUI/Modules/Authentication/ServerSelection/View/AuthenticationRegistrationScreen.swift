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

@available(iOS 14.0, *)
@MainActor struct AuthenticationRegistrationScreen: View {

    // MARK: - Properties
    
    // MARK: Private
    
    @Environment(\.theme) private var theme: ThemeSwiftUI
    
    // MARK: Public
    
    @ObservedObject var viewModel: AuthenticationRegistrationViewModel.Context
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                
                serverInfo
                    .padding(.leading, 12)
                
                Divider()
                    .padding(.vertical, 21)
                
                if viewModel.viewState.showRegistrationForm {
                    registrationForm
                }
                
                if viewModel.viewState.showRegistrationForm && viewModel.viewState.showSSOButtons {
                    Text(VectorL10n.or)
                        .foregroundColor(theme.colors.secondaryContent)
                        .padding(.top, 16)
                }
                
                if viewModel.viewState.showSSOButtons {
                    ssoButtons
                        .padding(.top, 16)
                }
                
            }
            .padding(.horizontal, 16)
        }
        .accentColor(theme.colors.accent)
        .background(theme.colors.background.ignoresSafeArea())
    }
    
    var header: some View {
        VStack(spacing: 8) {
            Image(Asset.Images.onboardingCongratulationsIcon.name)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(theme.colors.accent)
                .frame(width: 90, height: 90)
                .background(Circle().foregroundColor(.white).padding(2))
                .padding(.bottom, 8)
                .accessibilityHidden(true)
            
            Text(VectorL10n.onboardingRegistrationTitle)
                .font(theme.fonts.title2B)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.colors.primaryContent)
            
            Text(VectorL10n.onboardingRegistrationMessage)
                .font(theme.fonts.body)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.colors.secondaryContent)
        }
    }
    
    var serverInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(VectorL10n.onboardingRegistrationServerTitle)
                .font(theme.fonts.subheadline)
                .foregroundColor(theme.colors.secondaryContent)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.viewState.homeserverString)
                        .font(theme.fonts.body)
                        .foregroundColor(theme.colors.primaryContent)
                    
                    if let serverDescription = viewModel.viewState.serverDescription {
                        Text(serverDescription)
                            .font(theme.fonts.caption1)
                            .foregroundColor(theme.colors.tertiaryContent)
                    }
                }
                
                Spacer()
                
                Button { viewModel.send(viewAction: .selectServer) } label: {
                    Text(VectorL10n.edit)
                        .font(theme.fonts.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.colors.accent))
                }
            }
        }
    }
    
    var registrationForm: some View {
        VStack(spacing: 21) {
            RoundedBorderTextField(title: nil,
                                   placeHolder: VectorL10n.onboardingRegistrationUsername,
                                   text: $viewModel.username,
                                   footerText: VectorL10n.onboardingRegistrationUsernameFooter,
                                   isError: false,
                                   isFirstResponder: false,
                                   configuration: UIKitTextInputConfiguration(returnKeyType: .default,
                                                                              autocapitalizationType: .none,
                                                                              autocorrectionType: .no),
                                   onTextChanged: nil,
                                   onEditingChanged: nil)
            
            RoundedBorderTextField(title: nil,
                                   placeHolder: VectorL10n.authPasswordPlaceholder,
                                   text: $viewModel.password,
                                   footerText: VectorL10n.onboardingRegistrationPasswordFooter,
                                   isError: false,
                                   isFirstResponder: false,
                                   configuration: UIKitTextInputConfiguration(isSecureTextEntry: true),
                                   onTextChanged: nil,
                                   onEditingChanged: nil)
            
            Button { viewModel.send(viewAction: .next) } label: {
                Text(VectorL10n.next)
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
    }
    
    var ssoButtons: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.viewState.ssoIdentityProviders) { provider in
                AuthenticationSSOButton(provider: provider) {
                    
                }
            }
        }
    }
}

// MARK: - Previews

//@available(iOS 14.0, *)
//struct AuthenticationRegistration_Previews: PreviewProvider {
//    static let stateRenderer = MockAuthenticationRegistrationScreenState.stateRenderer
//    static var previews: some View {
//        stateRenderer.screenGroup(addNavigation: true)
//            .navigationViewStyle(.stack)
//    }
//}
