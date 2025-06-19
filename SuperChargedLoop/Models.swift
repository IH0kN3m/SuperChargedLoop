//
//  Models.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 3/31/25.
//

import Foundation
import SwiftUI

/// Namespace for all model types used in SuperChargedLoop.
enum Models {
    /// The different types of tiles available in the game.
    enum TileType: CaseIterable { case t0, t1, t2, t3, t4, t5 }

    /// Represents the four possible rotation points (0°, 90°, 180°, 270°) for a tile.
    enum RotationPoint: Int, CaseIterable, Equatable {
        case r0 = 0
        case r90 = 90
        case r180 = 180
        case r270 = 270

        /// Returns the next rotation point (rotated by 90° clockwise).
        func rotated() -> Self {
            return switch self {
            case .r0: .r90
            case .r90: .r180
            case .r180: .r270
            case .r270: .r0
            }
        }

        /// Returns the number of 90° rotations from the default orientation.
        func rotationNumbers() -> Int {
            switch self {
            case .r0: 0
            case .r90: 1
            case .r180: 2
            case .r270: 3
            }
        }
    }

    /// Represents a position in the grid.
    struct Position: Equatable, Hashable {
        let x: Int
        let y: Int
    }

    /// Represents an open connection on a tile at a specific position and rotation.
    struct OpenConnection: Equatable {
        let position: Position
        let connectionPoint: RotationPoint
    }

    /// Represents a single tile in the grid.
    class Tile: Identifiable, ObservableObject {
        /// Unique identifier for the tile.
        let id = UUID()
        /// The type of tile (shape/connection type).
        let type: TileType
        /// The current connection points for this tile, based on its type and rotation.
        @Published private(set) var connectionPoints: [RotationPoint]
        /// The tile's position in the grid.
        private(set) var position: Position
        /// The current rotation of the tile.
        @Published private(set) var rotation: RotationPoint
        /// The number of 90° rotations applied to the tile.
        @Published private(set) var rotationCount: Int
        /// The SwiftUI image asset for this tile.
        var asset: Image {
            switch type {
            case .t0: Image("t0")
            case .t1: Image("t1")
            case .t2: Image("t2")
            case .t3: Image("t3")
            case .t4: Image("t4")
            case .t5: Image("t5")
            }
        }

        /// Initializes a tile with a given type, position, and rotation.
        /// - Parameters:
        ///   - type: The tile type.
        ///   - position: The position in the grid.
        ///   - rotation: The initial rotation.
        init(
            type: TileType,
            position: Position,
            rotation: RotationPoint
        ) {
            self.type = type
            self.position = position
            self.rotation = rotation
            self.rotationCount = rotation.rotationNumbers()

            // Base connection points in their default orientation (.r0)
            connectionPoints = switch type {
            case .t0: []
            case .t1: [.r0]
            case .t2: [.r90, .r270]
            case .t3: [.r180, .r270]
            case .t4: [.r0, .r90, .r180]
            case .t5: [.r0, .r90, .r180, .r270]
            }

            // Rotate the connection points to match the requested initial rotation
            for _ in 0..<rotation.rotationNumbers() {
                connectionPoints = connectionPoints.map { $0.rotated() }
            }
        }

        /// Default initializer for an empty tile.
        init() {
            self.type = .t0
            self.position = .init(x: 0, y: 0)
            self.rotation = .r0
            self.rotationCount = 0
            self.connectionPoints = []
        }

        /// Rotates the tile by 90° clockwise, updating its rotation and connection points.
        func rotate() {
            rotation = rotation.rotated()
            rotationCount += 1
            connectionPoints = connectionPoints.map { $0.rotated() }
        }
    }
}
