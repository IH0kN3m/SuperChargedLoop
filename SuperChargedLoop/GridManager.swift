import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Handles everything related to grid generation, tile rotation and sizing. Keeps heavy logic out of `ViewModel`.
final class GridManager {
    // MARK: Public surface

    /// Calculates the ideal tile size for a given grid + density level.
    /// Must be called from the main actor as it queries UIKit window metrics.
    @MainActor
    func tileSize(for grid: [[Models.Tile]], isDense: Bool) -> CGFloat {
        guard !grid.isEmpty else { return isDense ? 20 : 48 }
        let gridWidth  = grid.first?.count ?? 0
        let gridHeight = grid.count
        let (availW, availH) = windowDimensions
        let minTile: CGFloat = isDense ? 20 : 40
        let maxTile         = min(availW / CGFloat(gridWidth), availH / CGFloat(gridHeight))
        return min(max(maxTile, minTile), 64)
    }

    /// Generates a new solvable matrix and accompanying metadata.
    /// Returns: grid, openConnections, requiresScroll, matrixSize
    func generateGrid(
        densityLevel: DensityLevel,
        isDense: Bool,
        customRows: Int,
        customCols: Int
    ) async -> (grid: [[Models.Tile]],
                openConnections: [Models.OpenConnection],
                requiresScroll: Bool,
                matrixSize: (Int, Int)) {
        let shouldMirror      = densityLevel != .scrolling && Bool.random()
        let mirrorHorizontally = shouldMirror && Bool.random()
        let mirrorVertically   = shouldMirror && Bool.random()

        let (availW, availH) = await MainActor.run { self.windowDimensions }
        let maxCols = Int(availW / (isDense ? 20 : 40))
        let maxRows = Int(availH / (isDense ? 20 : 40))

        // Determine matrix size
        let matrixSize: (Int, Int)
        switch densityLevel {
        case .scrolling:
            matrixSize = (customRows, customCols)
        default:
            if shouldMirror {
                let rows = weightedRandom(in: 2...min(8, maxRows), power: 2.0)
                let cols = weightedRandom(in: 2...min(16, maxCols), power: 2.0)
                matrixSize = (
                    rows.isMultiple(of: 2) ? rows : rows + 1,
                    cols.isMultiple(of: 2) ? cols : cols + 1
                )
            } else {
                let rows = weightedRandom(in: 2...min(8, maxRows), power: 2.0)
                let cols = weightedRandom(in: 2...min(17, maxCols), power: 2.0)
                matrixSize = (rows, cols)
            }
        }

        // Generate tiles via MatrixEngine
        let result = matrixEngine.generateGrid(
            matrixSize: matrixSize,
            mirrorHoriz: mirrorHorizontally,
            mirrorVert: mirrorVertically
        )

        // If we hit the rare all-blank grid, recurse
        if !result.grid.contains(where: { $0.contains(where: { $0.type != .t0 }) }) {
            return await generateGrid(
                densityLevel: densityLevel,
                isDense:      isDense,
                customRows:   customRows,
                customCols:   customCols
            )
        }

        let requiresScroll = matrixSize.1 > maxCols || matrixSize.0 > maxRows
        return (result.grid, result.openConnections, requiresScroll, matrixSize)
    }

    /// Re-evaluates open connections after a tile rotation.
    func recalculateConnections(
        for position: Models.Position,
        in grid: [[Models.Tile]],
        openConnections: [Models.OpenConnection]
    ) -> [Models.OpenConnection] {
        let result = matrixEngine.recalculateConnections(
            for: position,
            in: grid,
            openConnections: openConnections
        )
        return result.openConnections
    }

    // MARK: - Private
    private let matrixEngine = MatrixEngine()

    /// Window dimensions taking safe-area and a 16-pt padding into account.
    @MainActor
    private var windowDimensions: (CGFloat, CGFloat) {
        #if canImport(UIKit)
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window      = windowScene?.windows.first
        let insets      = window?.safeAreaInsets ?? .zero
        let width  = ((window?.bounds.width  ?? UIScreen.main.bounds.width)  - insets.left - insets.right) - 16
        let height = ((window?.bounds.height ?? UIScreen.main.bounds.height) - insets.top  - insets.bottom) - 16
        return (width, height)
        #else
        return (0, 0)
        #endif
    }

    /// Skewed-distribution helper favouring the upper bound.
    private func weightedRandom(in range: ClosedRange<Int>, power: Double) -> Int {
        let values  = Array(range)
        let weights = values.map { pow(Double($0 - range.lowerBound + 1), power) }
        let total   = weights.reduce(0, +)
        let roll    = Double.random(in: 0..<total)
        var cumulative = 0.0
        for (idx, weight) in weights.enumerated() {
            cumulative += weight
            if roll < cumulative { return values[idx] }
        }
        return values.last!
    }
} 