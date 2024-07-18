//
//  ContentView.swift
//  HandPoseTicTacToe
//
//  Created by Ace on 18/7/2024.
//

import SwiftUI

struct HandPoseTicTacToeView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @StateObject private var gameViewModel = TicTacToeGameViewModel()

    var body: some View {
        ZStack {
            if let frameImage = cameraViewModel.frameImage {
                HandPoseImageView(handPoseImage: frameImage)
                    .opacity(0.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottomTrailing) {
                        CircularProgressView(
                            pct: cameraViewModel.readingPct,
                            readingNumber: cameraViewModel.readingNumber,
                            recognisedNumber: cameraViewModel.recognisedNumber
                        )
                    }
                    .overlay(alignment: .topLeading) {
                        VStack {
                            Text("\(gameViewModel.message)")
                                .font(.system(size: 30))
                                .padding(.top, 30)
                            Text("\(gameViewModel.boardString)")
                                .font(.system(size: 90))
                                .bold()
                        }
                        .padding()
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
        .onChange(of: cameraViewModel.recognisedNumber) { oldValue, newValue in
            if let cellNumber = Int(newValue) {
                switch cellNumber {
                case 10:
                    gameViewModel.resetGame()
                default:
                    gameViewModel.humanMove(cell: cellNumber)
                }
            }
        }
    }
}

#Preview {
    HandPoseTicTacToeView()
}
