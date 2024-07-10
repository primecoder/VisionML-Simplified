//
//  ContentView.swift
//  HandPoseCountingMac
//
//  Created by Ace on 2/7/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @StateObject private var gameViewModel = TicTacToeGameViewModel()

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
                    .overlay {
                        Text("\(gameViewModel.game.boardString())")
                            .font(.system(size: 90))
                            .bold()
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
                    gameViewModel.game.resetBoard()
                default:
                    gameViewModel.game.playMove(cell: cellNumber, player: .human)
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                        if let bestMove = gameViewModel.game.findBestMove() {
                            gameViewModel.game.playMove(cell: bestMove, player: .ai)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
