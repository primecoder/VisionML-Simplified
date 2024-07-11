//
//  TicTacToeGameViewModel.swift
//  HandPoseCountingMac
//
//  Created by Ace on 10/7/2024.
//

import Foundation
import TicTacToeMinimax

class TicTacToeGameViewModel: ObservableObject {

    var game = TicTacToeGame()
    
    @Published @MainActor var message: String = "Your move"
    @MainActor var boardString: String { game.boardString() }

    @MainActor
    func resetGame() {
        game.resetBoard()
        message = "New Game"
    }

    @MainActor
    func humanMove(cell: Int) {
        do {
            try game.playMove(cell: cell, player: .human)
            message = "AI thinking ..."
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [self] in
                if let bestMove = game.findBestMove() {
                    do {
                        try game.playMove(cell: bestMove, player: .ai)
                        let msg = game.status == .playing ? "Your move" : "\(game.status)"
                        message = "\(msg)"
                    } catch {
                        message = "Error finding move for AI!"
                    }
                } else {
                    message = "\(game.status)"  // Draw
                }
            }
        } catch {
            message = "Invalid move!"
        }
    }
}
