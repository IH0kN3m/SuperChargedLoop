//
//  Models.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 3/31/25.
//

import Foundation
import SwiftUI

enum Models {
    enum TileType: CaseIterable { case t0, t1, t2, t3, t4, t5 }
    enum RotationPoint: Int, CaseIterable, Equatable {
        case r0 = 0
        case r90 = 90
        case r180 = 180
        case r270 = 270

        /// Rotates itself by 90 degrees.
        func rotated() -> Self {
            return switch self {
            case .r0: .r90
            case .r90: .r180
            case .r180: .r270
            case .r270: .r0
            }
        }

        func rotationNumbers() -> Int {
            switch self {
            case .r0: 0
            case .r90: 1
            case .r180: 2
            case .r270: 3
            }
        }
    }

    struct Position: Equatable, Hashable {
        let x: Int
        let y: Int
    }

    struct OpenConnection: Equatable {
        let position: Position
        let connectionPoint: RotationPoint
    }

    class Tile: Identifiable, ObservableObject {
        let id = UUID()
        let type: TileType
        @Published private(set) var connectionPoints: [RotationPoint]

        private(set) var position: Position
        @Published private(set) var rotation: RotationPoint
        @Published private(set) var rotationCount: Int

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

        init() {
            self.type = .t0
            self.position = .init(x: 0, y: 0)
            self.rotation = .r0
            self.rotationCount = 0
            self.connectionPoints = []
        }

        func rotate() {
            rotation = rotation.rotated()
            rotationCount += 1
            connectionPoints = connectionPoints.map { $0.rotated() }
        }
    }
}
