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

import SwiftUI

@available(iOS 14.0, *)
struct AuthenticationSSOButton: View {
    
    enum Brand: String {
        case apple, facebook, github, gitlab, google, twitter
    }
    
    @Environment(\.theme) private var theme
    
    let provider: SSOIdentityProvider
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                icon
                    .alignmentGuide(.leading) { $0[.leading] }
                
                Spacer()
                
                Text(VectorL10n.socialLoginButtonTitleContinue(provider.name))
                    .foregroundColor(theme.colors.primaryContent)
                    .alignmentGuide(HorizontalAlignment.center) { $0[HorizontalAlignment.center] }
                
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(SecondaryActionButtonStyle(customColor: theme.colors.quinaryContent))
    }
    
    @ViewBuilder
    var icon: some View {
        switch provider.brand {
        case Brand.apple.rawValue:
            Image(Asset.Images.socialLoginButtonApple.name)
                .accentColor(theme.colors.primaryContent)
        case Brand.facebook.rawValue:
            Image(Asset.Images.socialLoginButtonFacebook.name)
                .accentColor(theme.colors.primaryContent)
        case Brand.github.rawValue:
            Image(Asset.Images.socialLoginButtonGithub.name)
                .accentColor(theme.colors.primaryContent)
        case Brand.gitlab.rawValue:
            Image(Asset.Images.socialLoginButtonGitlab.name)
                .accentColor(theme.isDark ? theme.colors.primaryContent : nil)
        case Brand.google.rawValue:
            Image(Asset.Images.socialLoginButtonGoogle.name)
                .accentColor(theme.isDark ? theme.colors.primaryContent : nil)
        case Brand.twitter.rawValue:
            Image(Asset.Images.socialLoginButtonTwitter.name)
                .accentColor(theme.colors.primaryContent)
        default:
            EmptyView()
        }
    }
}
