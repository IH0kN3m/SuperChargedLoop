//
//  ViewModel.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 6/19/25.
//

import SwiftUI
import Foundation
import CoreHaptics

class ViewModel: ObservableObject {
    private let matrixEngine = MatrixEngine()

    @MainActor
    private let impactFeedback = UIImpactFeedbackGenerator(
        style: .light
    )

    @Published
    @MainActor
    var grid: [[Models.Tile]] = []

    @Published
    @MainActor
    var openConnections: [Models.OpenConnection] = []
    
    @Published
    @MainActor
    var selectedColorPair: (pastel: Color, darker: Color) = (Color.blue, Color.blue)

    private let colorPairs = [
        (Color(red: 1.0, green: 0.7, blue: 0.7), Color(red: 0.8, green: 0.5, blue: 0.5)),
        (Color(red: 1.0, green: 0.8, blue: 0.6), Color(red: 0.8, green: 0.6, blue: 0.4)),
        (Color(red: 1.0, green: 1.0, blue: 0.7), Color(red: 0.8, green: 0.8, blue: 0.5)),
        (Color(red: 0.7, green: 1.0, blue: 0.7), Color(red: 0.5, green: 0.8, blue: 0.5)),
        (Color(red: 0.7, green: 0.8, blue: 1.0), Color(red: 0.5, green: 0.6, blue: 0.8)),
        (Color(red: 0.9, green: 0.7, blue: 1.0), Color(red: 0.7, green: 0.5, blue: 0.8)),
        (Color(red: 1.0, green: 0.7, blue: 0.9), Color(red: 0.8, green: 0.5, blue: 0.7)),
        (Color(red: 0.7, green: 1.0, blue: 0.9), Color(red: 0.5, green: 0.8, blue: 0.7)),
        (Color(red: 0.7, green: 0.9, blue: 0.9), Color(red: 0.5, green: 0.7, blue: 0.7)),
        (Color(red: 0.7, green: 0.9, blue: 1.0), Color(red: 0.5, green: 0.7, blue: 0.8)),
        (Color(red: 0.8, green: 0.8, blue: 1.0), Color(red: 0.6, green: 0.6, blue: 0.8)),
        (Color(red: 0.9, green: 0.8, blue: 0.7), Color(red: 0.7, green: 0.6, blue: 0.5)),
        (Color(red: 0.9, green: 0.9, blue: 0.9), Color(red: 0.7, green: 0.7, blue: 0.7))
    ]

    func generateGrid() {
        Task {
            let matrixSize = (Int.random(in: 2...8), Int.random(in: 2...17))
            let result = matrixEngine.generateGrid(matrixSize: matrixSize)
            await MainActor.run {
                grid = result.grid
                openConnections = result.openConnections
                selectRandomColorPair()
            }
        }
    }

    @MainActor
    func selectRandomColorPair() {
        selectedColorPair = colorPairs.randomElement() ?? (
            Color(red: 0.7, green: 0.8, blue: 1.0), Color(red: 0.5, green: 0.6, blue: 0.8)
        )
    }

    func rotateElement(at position: Models.Position) {
        // 1. Perform the visual rotation immediately on the main thread so the UI feels instantaneous.
        Task { @MainActor in
            guard position.y < grid.count, position.x < grid[position.y].count else { return }
            grid[position.y][position.x].rotate()
            impactFeedback.impactOccurred()
        }

        // 2. Launch a background task (utility priority) for the heavy bookkeeping.
        Task(priority: .utility) {
            let grid = await grid
            let openConnections = await openConnections
            let result = matrixEngine.recalculateConnections(
                for: position,
                in: grid,
                openConnections: openConnections
            )

            await MainActor.run {
                // Only update the openConnections array. The grid reference is identical (we mutated in-place).
                self.openConnections = result.openConnections
            }
        }
    }
}
