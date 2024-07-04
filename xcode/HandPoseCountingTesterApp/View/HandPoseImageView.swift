//
//  HandPoseImageView.swift
//  HandPoseCountingTesterApp
//
//  Created by Ace on 2/7/2024.
//

import SwiftUI

struct HandPoseImageView: View {
    var handPoseImage: HandPoseImage
    var body: some View {
#if os(macOS)
        Image(nsImage: handPoseImage)
            .resizable()
            .scaledToFit()
#else
        Image(uiImage: handPoseImage)
            .resizable()
            .scaledToFit()
#endif
    }
}

