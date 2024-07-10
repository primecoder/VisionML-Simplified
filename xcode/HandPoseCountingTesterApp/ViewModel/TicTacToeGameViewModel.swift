//
//  TicTacToeGameViewModel.swift
//  HandPoseCountingMac
//
//  Created by Ace on 10/7/2024.
//

import Foundation
import TicTacToeMinimax

class TicTacToeGameViewModel: ObservableObject {

    @Published @MainActor var game = TicTacToeGame()
}
