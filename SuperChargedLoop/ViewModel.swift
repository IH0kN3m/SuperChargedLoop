//
//  ViewModel.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 6/19/25.
//

import SwiftUI
import Foundation
import CoreHaptics
#if canImport(UIKit)
import UIKit
#endif

/// The density level for the grid, affecting its size and scrollability.
public enum DensityLevel: String, CaseIterable, Identifiable, Codable {
    case normal
    case dense
    case scrolling
    public var id: String { rawValue }
}

/// The main view model for SuperChargedLoop, managing the grid, user settings, and game logic.
class ViewModel: ObservableObject {
    /// Keys for persisting user settings in UserDefaults.
    private enum DefaultsKey {
        static let density = "densityLevel"
        static let customRows = "customRows"
        static let customCols = "customCols"
        static let haptics = "hapticsEnabled"
        static let tapBackgroundToRegenerate = "tapBackgroundToRegenerateEnabled"
    }

    /// The engine responsible for generating and updating the tile matrix.
    private let matrixEngine = MatrixEngine()

    /// Haptic feedback generator for tile interactions.
    @MainActor
    private let impactFeedback = UIImpactFeedbackGenerator(
        style: .light
    )

    /// The current grid of tiles.
    @Published
    @MainActor
    var grid: [[Models.Tile]] = []

    /// The current list of open connections in the grid.
    @Published
    @MainActor
    var openConnections: [Models.OpenConnection] = []
    
    /// The currently selected color pair for the UI.
    @Published
    @MainActor
    var selectedColorPair: (pastel: Color, darker: Color) = (Color.blue, Color.blue)

    /// The selected density level for the grid.
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

    /// Custom number of rows for the grid (used in scrolling mode).
    @Published var customRows: Int = 4 {
        didSet { UserDefaults.standard.set(customRows, forKey: DefaultsKey.customRows) }
    }
    /// Custom number of columns for the grid (used in scrolling mode).
    @Published var customCols: Int = 8 {
        didSet { UserDefaults.standard.set(customCols, forKey: DefaultsKey.customCols) }
    }

    /// Whether the grid requires a scroll view for display.
    @Published var requiresScroll: Bool = false

    /// Returns true if the density level is set to dense.
    var isDense: Bool { densityLevel == .dense }

    /// Whether haptic feedback is enabled for tile interactions.
    @Published
    var hapticsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: DefaultsKey.haptics) }
    }

    /// Whether tapping the background regenerates the grid.
    @Published
    var tapBackgroundToRegenerate: Bool = false {
        didSet {
            UserDefaults.standard.set(
                tapBackgroundToRegenerate,
                forKey: DefaultsKey.tapBackgroundToRegenerate
            )
        }
    }

    /// The current window dimensions, accounting for safe area insets.
    @MainActor
    private var windowDimensions: (width: CGFloat, height: CGFloat) {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = windowScene?.windows.first
        let safeAreaInsets = window?.safeAreaInsets ?? .zero
        let width = ((window?.bounds.width ?? UIScreen.main.bounds.width) - safeAreaInsets.left - safeAreaInsets.right) - 16
        let height = ((window?.bounds.height ?? UIScreen.main.bounds.height) - safeAreaInsets.top - safeAreaInsets.bottom) - 16
        return (width, height)
    }

    /// The optimal tile size for the current grid and window size.
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

    /// The current matrix size (rows, columns).
    @MainActor
    var currentMatrixSize: (Int, Int) = (0, 0)

    /// Predefined color pairs for the UI.
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

    /// Initializes the view model and loads persisted user settings.
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

    /// Generates a new grid and updates the UI, using the current settings.
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

            guard result.grid.contains(where: { $0.contains(where: { $0.type != .t0 }) }) else {
                generateGrid()
                return
            }

            await MainActor.run {
                grid = result.grid
                openConnections = result.openConnections
                selectRandomColorPair()
            }
        }
    }

    /// Selects a random color pair for the UI, with animation.
    @MainActor
    func selectRandomColorPair() {
        withAnimation(.interpolatingSpring(duration: 0.20, bounce: 0.25)) {
            let pair = colorPairs.randomElement() ?? (
                Color(red: 0.7, green: 0.8, blue: 1.0), Color(red: 0.5, green: 0.6, blue: 0.8)
            )

            // Create a dynamic pastel that automatically adjusts for light / dark mode
            let dynamicPastel = adjustPastelForCurrentInterface(pair.1)

            selectedColorPair = (pastel: pair.0, darker: dynamicPastel)
        }
    }

    /// Returns a `Color` that automatically darkens when the interface switches to dark mode.
    /// - Parameters:
    ///   - color: The original pastel `Color` chosen for light mode.
    ///   - darkenFactor: Multiplier applied to RGB components for the dark-mode version (default 0.6 = 40 % darker).
    /// - Returns: A dynamic `Color` that adapts to the current interface style.
    private func adjustPastelForCurrentInterface(_ color: Color, darkenFactor: CGFloat = 0.6) -> Color {
#if canImport(UIKit)
        let lightUIColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard lightUIColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return color // Fallback if conversion fails
        }

        // Pre-compute the darker variant for dark mode
        let darkUIColor = UIColor(
            red: r * darkenFactor,
            green: g * darkenFactor,
            blue: b * darkenFactor,
            alpha: a
        )

        // Create a dynamic UIColor that swaps based on the current trait collection
        let dynamicUIColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? darkUIColor : lightUIColor
        }

        return Color(dynamicUIColor)
#else
        return color
#endif
    }

    /// Rotates a tile at the given position, updating the grid and open connections.
    /// - Parameter position: The position of the tile to rotate.
    func rotateElement(at position: Models.Position) {
        // 1. Perform the visual rotation immediately on the main thread so the UI feels instantaneous.
        Task { @MainActor in
            guard position.y < grid.count, position.x < grid[position.y].count else { return }
            let tile = grid[position.y][position.x]
            tile.rotate()
            if hapticsEnabled && tile.type != .t0 {
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

    /// Returns a random Int in the given range, biased toward higher values by the given power.
    /// - Parameters:
    ///   - range: The range of values.
    ///   - power: The exponent for weighting (higher = more bias toward higher values).
    /// - Returns: A random integer from the range.
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

    /// Sets the density level to dense or normal.
    func setDense(_ dense: Bool) {
        densityLevel = dense ? .dense : .normal
    }
    
    /// Enables or disables haptic feedback.
    func setHapticsEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
    }
    
    func regenerateLevel() {
        generateGrid()
    }
}
