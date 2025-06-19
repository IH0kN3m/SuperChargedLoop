//
//  ViewModel.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 6/19/25.
//

import SwiftUI
import Foundation

class ViewModel: ObservableObject {
    private let matrixEngine = MatrixEngine()

    @Published
    @MainActor
    var grid: [[Models.Tile]] = []

    @Published
    @MainActor
    var openConnections: [Models.OpenConnection] = []

    func generateGrid() {
        Task {
            let matrixSize = (Int.random(in: 2...9), Int.random(in: 2...18))
            let result = matrixEngine.generateGrid(matrixSize: matrixSize)
            await MainActor.run {
                grid = result.grid
                openConnections = result.openConnections
            }
        }
    }

    func rotateElement(at position: Models.Position) {
        Task {
            let result = await matrixEngine.rotateElement(
                at: position,
                in: grid,
                openConnections: openConnections
            )
            await MainActor.run {
                grid = result.grid
                openConnections = result.openConnections
            }
        }
    }
}
