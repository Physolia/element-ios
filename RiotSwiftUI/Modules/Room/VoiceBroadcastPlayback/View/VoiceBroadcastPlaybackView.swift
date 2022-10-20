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

struct VoiceBroadcastPlaybackView: View {
    // MARK: - Properties
    
    // MARK: Private
    
    @Environment(\.theme) private var theme: ThemeSwiftUI
    
    // MARK: Public
    
    @ObservedObject var viewModel: VoiceBroadcastPlaybackViewModel.Context
    
    var body: some View {
        let details = viewModel.viewState.details
        
        VStack(alignment: .leading, spacing: 16.0) {
            Text(details.senderDisplayName ?? "")
            //Text(VectorL10n.voiceBroadcastInTimelineTitle)
                .font(theme.fonts.bodySB)
                .foregroundColor(theme.colors.primaryContent)
            
            if viewModel.viewState.playbackState == .error {
                VoiceBroadcastPlaybackErrorView()
            } else {
                HStack(alignment: .top, spacing: 16.0) {
                    if viewModel.viewState.playbackState == .playing {
                        Button { viewModel.send(viewAction: .pause) } label: {
                            Image("voice_broadcast_pause")
                                .renderingMode(.original)
                        }
                        .accessibilityIdentifier("pauseButton")
                    } else {
                        Button { viewModel.send(viewAction: .play) } label: {
                            Image("voice_broadcast_play")
                                .renderingMode(.original)
                        }
                        .disabled(viewModel.viewState.playbackState == .buffering)
                        .accessibilityIdentifier("playButton")
                    }
                }
                .activityIndicator(show: viewModel.viewState.playbackState == .buffering)
            }

        }
        .padding([.horizontal, .top], 2.0)
        .padding([.bottom])
        .alert(item: $viewModel.alertInfo) { info in
            info.alert
        }
    }
}

// MARK: - Previews

struct VoiceBroadcastPlaybackView_Previews: PreviewProvider {
    static let stateRenderer = MockVoiceBroadcastPlaybackScreenState.stateRenderer
    static var previews: some View {
        stateRenderer.screenGroup()
    }
}
