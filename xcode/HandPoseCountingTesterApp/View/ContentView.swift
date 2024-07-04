//
//  ContentView.swift
//  HandPoseCountingMac
//
//  Created by Ace on 2/7/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()

    var body: some View {
        ZStack {
            if let frameImage = cameraViewModel.frameImage {
                HandPoseImageView(handPoseImage: frameImage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottomTrailing) {
                        CircularProgressView(
                            pct: cameraViewModel.readingPct,
                            readingNumber: cameraViewModel.readingNumber,
                            recognisedNumber: cameraViewModel.recognisedNumber
                        )
                    }
            } else {
                Text("No Camera Feed")
                    .foregroundColor(.white)
                    .background(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    ContentView()
}
