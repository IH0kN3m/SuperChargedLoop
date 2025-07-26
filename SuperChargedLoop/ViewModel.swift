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

    // External managers that encapsulate complex logic
    private let gridManager  = GridManager()
    private let colorManager = ColorManager()

    /// Haptic feedback generator for tile interactions.
    @MainActor
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

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

    // MARK: - Derived properties & public helpers

    /// Optimal tile dimension for the current grid & device window.
    @MainActor
    var tileSize: CGFloat { gridManager.tileSize(for: grid, isDense: isDense) }

    // Window-dimension and tile-size logic moved to ViewModel+Grid.swift
    // The following property is retained for external access.
    /// The current matrix size (rows, columns).
    @MainActor
    var currentMatrixSize: (Int, Int) = (0, 0)

    // Pre-defined colour pairs now live in ViewModel+Color.swift

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

    // MARK: - Grid & Colour orchestration

    /// Generates a new puzzle grid by delegating to `GridManager`.
    func generateGrid() {
        Task {
            let output = await gridManager.generateGrid(
                densityLevel: densityLevel,
                isDense:      isDense,
                customRows:   customRows,
                customCols:   customCols
            )

            await MainActor.run {
                self.grid            = output.grid
                self.openConnections = output.openConnections
                self.requiresScroll  = output.requiresScroll
                self.currentMatrixSize = output.matrixSize

                // Update colour theme
                self.selectedColorPair = colorManager.randomColorPair()
            }
        }
    }

    /// Handles user tile-rotation gestures.
    func rotateElement(at position: Models.Position) {
        // Visual update first so the UI feels snappy
        Task { @MainActor in
            guard position.y < grid.count, position.x < grid[position.y].count else { return }
            let tile = grid[position.y][position.x]
            tile.rotate()
            if hapticsEnabled && tile.type != .t0 {
                impactFeedback.impactOccurred()
            }
        }

        // Heavy connection bookkeeping off the main thread
        Task(priority: .utility) {
            let updatedOpen = gridManager.recalculateConnections(
                for: position,
                in: grid,
                openConnections: openConnections
            )
            await MainActor.run { self.openConnections = updatedOpen }
        }
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
