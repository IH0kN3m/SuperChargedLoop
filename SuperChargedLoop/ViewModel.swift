//
//  ViewModel.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 6/19/25.
//

import SwiftUI
import Foundation
import CoreHaptics

public enum DensityLevel: String, CaseIterable, Identifiable, Codable {
    case normal
    case dense
    case scrolling
    public var id: String { rawValue }
}

class ViewModel: ObservableObject {
    private enum DefaultsKey {
        static let density = "densityLevel"
        static let customRows = "customRows"
        static let customCols = "customCols"
        static let haptics = "hapticsEnabled"
        static let tapBackgroundToRegenerate = "tapBackgroundToRegenerateEnabled"
    }

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

    @Published
    var densityLevel: DensityLevel = .normal {
        didSet {
            // Reset custom sizes when density changes away from scrolling
            if densityLevel != .scrolling {
                customRows = 4
                customCols = 8
            }
            UserDefaults.standard.set(densityLevel.rawValue, forKey: DefaultsKey.density)
        }
    }

    // Custom matrix size when scrolling density is selected
    @Published var customRows: Int = 4 {
        didSet { UserDefaults.standard.set(customRows, forKey: DefaultsKey.customRows) }
    }
    @Published var customCols: Int = 8 {
        didSet { UserDefaults.standard.set(customCols, forKey: DefaultsKey.customCols) }
    }

    // Determines if the current grid should be displayed inside ScrollView
    @Published var requiresScroll: Bool = false

    // Convenience computed properties
    var isDense: Bool { densityLevel == .dense }

    @Published
    var hapticsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: DefaultsKey.haptics) }
    }

    @Published
    var tapBackgroundToRegenerate: Bool = false {
        didSet {
            UserDefaults.standard.set(
                tapBackgroundToRegenerate,
                forKey: DefaultsKey.tapBackgroundToRegenerate
            )
        }
    }

    @MainActor
    private var windowDimensions: (width: CGFloat, height: CGFloat) {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        let safeAreaInsets = window?.safeAreaInsets ?? .zero
        let width = ((window?.bounds.width ?? UIScreen.main.bounds.width) - safeAreaInsets.left - safeAreaInsets.right) - 16
        let height = ((window?.bounds.height ?? UIScreen.main.bounds.height) - safeAreaInsets.top - safeAreaInsets.bottom) - 16
        return (width, height)
    }

    @MainActor
    var tileSize: CGFloat {
        guard !grid.isEmpty else { return isDense ? 20 : 48 }
        let gridWidth = grid[0].count
        let gridHeight = grid.count
        let (availableWidth, availableHeight) = windowDimensions
        let minTile: CGFloat = isDense ? 20 : 40
        let maxTileSize = min(availableWidth / CGFloat(gridWidth), availableHeight / CGFloat(gridHeight))
        return min(max(maxTileSize, minTile), 64)
    }

    @MainActor
    var currentMatrixSize: (Int, Int) = (0, 0)

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

    init() {
        // Load persisted settings
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: DefaultsKey.density), let lvl = DensityLevel(rawValue: raw) {
            densityLevel = lvl
        }
        customRows = defaults.integer(forKey: DefaultsKey.customRows)
        if customRows == 0 { customRows = 4 }
        customCols = defaults.integer(forKey: DefaultsKey.customCols)
        if customCols == 0 { customCols = 8 }
        hapticsEnabled = defaults.bool(forKey: DefaultsKey.haptics)
        tapBackgroundToRegenerate = defaults.bool(forKey: DefaultsKey.tapBackgroundToRegenerate)
    }

    func generateGrid() {
        Task {
            let canMirror = densityLevel != .scrolling
            let shouldMirror = canMirror && Bool.random()
            let shouldMirrorHorizontally = shouldMirror && Bool.random()
            let shouldMirrorVertically = shouldMirror && Bool.random()

            let (availableWidth, availableHeight) = await windowDimensions
            let maxCols = Int(availableWidth / (isDense ? 20 : 40))
            let maxRows = Int(availableHeight / (isDense ? 20 : 40))

            // Determine target matrix size
            let matrixSize: (Int, Int)
            if densityLevel == .scrolling {
                matrixSize = (customRows, customCols)
            } else {
                // Preserve existing logic for normal/dense
                if shouldMirror {
                    let rows = weightedRandom(in: 2...min(8, maxRows), power: 2.0)
                    let cols = weightedRandom(in: 2...min(16, maxCols), power: 2.0)
                    matrixSize = (
                        rows % 2 == 0 ? rows : rows + 1,
                        cols % 2 == 0 ? cols : cols + 1
                    )
                } else {
                    let rows = weightedRandom(in: 2...min(8, maxRows), power: 2.0)
                    let cols = weightedRandom(in: 2...min(17, maxCols), power: 2.0)
                    matrixSize = (rows, cols)
                }
            }
            
            // Mirror options already determined earlier in this Task.

            // Determine if scrolling needed
            await MainActor.run {
                requiresScroll = matrixSize.1 > maxCols || matrixSize.0 > maxRows
                currentMatrixSize = matrixSize
            }

            let result = matrixEngine.generateGrid(
                matrixSize: matrixSize,
                mirrorHoriz: shouldMirrorHorizontally,
                mirrorVert: shouldMirrorVertically
            )
            await MainActor.run {
                grid = result.grid
                openConnections = result.openConnections
                selectRandomColorPair()
            }
        }
    }

    @MainActor
    func selectRandomColorPair() {
        withAnimation(.interpolatingSpring(duration: 0.20, bounce: 0.25)) {
            selectedColorPair = colorPairs.randomElement() ?? (
                Color(red: 0.7, green: 0.8, blue: 1.0), Color(red: 0.5, green: 0.6, blue: 0.8)
            )
        }
    }

    func rotateElement(at position: Models.Position) {
        // 1. Perform the visual rotation immediately on the main thread so the UI feels instantaneous.
        Task { @MainActor in
            guard position.y < grid.count, position.x < grid[position.y].count else { return }
            grid[position.y][position.x].rotate()
            if hapticsEnabled {
                impactFeedback.impactOccurred()
            }
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

    // Returns a random Int in the given range, biased toward higher values by the given power
    private func weightedRandom(in range: ClosedRange<Int>, power: Double = 2.0) -> Int {
        let values = Array(range)
        let weights = values.map { pow(Double($0 - range.lowerBound + 1), power) }
        let totalWeight = weights.reduce(0, +)
        let random = Double.random(in: 0..<totalWeight)
        var cumulative = 0.0
        for (index, weight) in weights.enumerated() {
            cumulative += weight
            if random < cumulative {
                return values[index]
            }
        }
        return values.last!
    }

    func setDense(_ dense: Bool) {
        densityLevel = dense ? .dense : .normal
    }
    
    func setHapticsEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
    }
    
    func regenerateLevel() {
        generateGrid()
    }
}
