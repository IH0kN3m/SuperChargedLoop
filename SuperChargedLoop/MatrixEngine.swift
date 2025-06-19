//
//  MatrixEngine.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 3/31/25.
//

import Foundation

class MatrixEngine {
    func generateGrid(matrixSize: (Int, Int)) -> (grid: [[Models.Tile]], openConnections: [Models.OpenConnection]) {
        let x = matrixSize.0
        let y = matrixSize.1
        
        var grid: [[Models.Tile]] = []
        
        for j in 0..<y {
            var row: [Models.Tile] = []
            for i in 0..<x {
                var neighbors: [Models.Tile] = []
                if i > 0 { neighbors.append(row[i - 1]) }
                if j > 0 { neighbors.append(grid[j - 1][i]) }
                
                var candidates: [Models.Tile] = []
                for type in Models.TileType.allCases {
                    for rotation in Models.RotationPoint.allCases {
                        let tile = Models.Tile(
                            type: type,
                            position: .init(x: i, y: j),
                            rotation: rotation
                        )
                        
                        let hasOutOfBoundConnectionPoints =
                        if i == 0 && tile.connectionPoints.contains(.r270) { true }
                        else if i == x - 1 && tile.connectionPoints.contains(.r90) { true }
                        else if j == 0 && tile.connectionPoints.contains(.r0) { true }
                        else if j == y - 1 && tile.connectionPoints.contains(.r180) { true }
                        else { false }
                        guard !hasOutOfBoundConnectionPoints else { continue }
                        
                        var isValid = true
                        for neighbor in neighbors {
                            if neighbor.position.x == i - 1 && neighbor.position.y == j { // left
                                let neighborWantsToConnect = neighbor.connectionPoints.contains(.r90)
                                let tileWantsToConnect = tile.connectionPoints.contains(.r270)
                                if neighborWantsToConnect != tileWantsToConnect {
                                    isValid = false
                                    break
                                }
                            } else if neighbor.position.x == i && neighbor.position.y == j - 1 { // top
                                let neighborWantsToConnect = neighbor.connectionPoints.contains(.r180)
                                let tileWantsToConnect = tile.connectionPoints.contains(.r0)
                                if neighborWantsToConnect != tileWantsToConnect {
                                    isValid = false
                                    break
                                }
                            }
                        }
                        
                        if isValid { candidates.append(tile) }
                    }
                }
                
                guard !candidates.isEmpty else {
                    return generateGrid(matrixSize: matrixSize)
                }
                
                row.append(candidates.randomElement() ?? .init())
            }
            grid.append(row)
        }
        
        let shuffledResult = shuffleTilesWithRandomRotations(grid: grid)
        return (grid: shuffledResult.grid, openConnections: shuffledResult.openConnections)
    }
    
    func rotateElement(at position: Models.Position, in grid: [[Models.Tile]], openConnections: [Models.OpenConnection]) -> (grid: [[Models.Tile]], openConnections: [Models.OpenConnection]) {
        let updatedGrid = grid
        var updatedOpenConnections = openConnections
        
        // Check if position is valid
        guard position.y >= 0 && position.y < updatedGrid.count,
              position.x >= 0 && position.x < updatedGrid[position.y].count else { 
            return (grid: updatedGrid, openConnections: updatedOpenConnections) 
        }
        
        // Rotate the element by 90 degrees
        updatedGrid[position.y][position.x].rotate()
        
        var neighbors: [Models.Tile] = []
        if position.x > 0 { neighbors.append(updatedGrid[position.y][position.x - 1]) }
        if position.x < updatedGrid[position.y].count - 1 { neighbors.append(updatedGrid[position.y][position.x + 1]) }
        if position.y > 0 { neighbors.append(updatedGrid[position.y - 1][position.x]) }
        if position.y < updatedGrid.count - 1 { neighbors.append(updatedGrid[position.y + 1][position.x]) }

        let affectedTiles = [updatedGrid[position.y][position.x]] + neighbors
        let affectedPositions = affectedTiles.map { $0.position }
        
        // First, remove all existing mismatches for this element and its neighbors
        updatedOpenConnections.removeAll { affectedPositions.contains($0.position) }

        // Re-check open connections for all affected tiles
        for tile in affectedTiles {
            var tileNeighbors: [Models.Tile] = []
            if tile.position.x > 0 { tileNeighbors.append(updatedGrid[tile.position.y][tile.position.x - 1]) }
            if tile.position.x < updatedGrid[tile.position.y].count - 1 { tileNeighbors.append(updatedGrid[tile.position.y][tile.position.x + 1]) }
            if tile.position.y > 0 { tileNeighbors.append(updatedGrid[tile.position.y - 1][tile.position.x]) }
            if tile.position.y < updatedGrid.count - 1 { tileNeighbors.append(updatedGrid[tile.position.y + 1][tile.position.x]) }

            updatedOpenConnections.append(
                contentsOf: checkOpenConnections(
                    of: tile,
                    with: tileNeighbors
                )
            )
        }
        
        return (grid: updatedGrid, openConnections: updatedOpenConnections)
    }
    
    private func shuffleTilesWithRandomRotations(grid: [[Models.Tile]]) -> (grid: [[Models.Tile]], openConnections: [Models.OpenConnection]) {
        let updatedGrid = grid
        var openConnections: [Models.OpenConnection] = []
        
        for j in 0..<updatedGrid.count {
            for i in 0..<updatedGrid[j].count {
                // Apply random rotation
                let randomRotation = Models.RotationPoint.allCases.randomElement() ?? .r0
                for _ in 0..<randomRotation.rotationNumbers() {
                    updatedGrid[j][i].rotate()
                }
            }
        }

        for j in 0..<updatedGrid.count {
            for i in 0..<updatedGrid[j].count {
                // Check open connections for this tile
                var neighbors: [Models.Tile] = []
                if i > 0 { neighbors.append(updatedGrid[j][i - 1]) }
                if j > 0 { neighbors.append(updatedGrid[j - 1][i]) }
                if i < updatedGrid[j].count - 1 { neighbors.append(updatedGrid[j][i + 1]) }
                if j < updatedGrid.count - 1 { neighbors.append(updatedGrid[j + 1][i]) }
                
                let tileOpenConnections = checkOpenConnections(of: updatedGrid[j][i], with: neighbors)
                openConnections.append(contentsOf: tileOpenConnections)
            }
        }
        
        return (grid: updatedGrid, openConnections: openConnections)
    }
    
    private func checkOpenConnections(
        of tile: Models.Tile,
        with neighbors: [Models.Tile]
    ) -> [Models.OpenConnection] {
        let neighborPositions: [Models.Position] = [
            .init(x: tile.position.x, y: tile.position.y - 1),
            .init(x: tile.position.x + 1, y: tile.position.y),
            .init(x: tile.position.x, y: tile.position.y + 1),
            .init(x: tile.position.x - 1, y: tile.position.y)
        ]
        var foundNeighbors: [Models.Tile?] = Array(repeating: nil, count: 4)
        for neighbor in neighbors {
            for (index, position) in neighborPositions.enumerated() {
                if neighbor.position.x == position.x && neighbor.position.y == position.y {
                    foundNeighbors[index] = neighbor
                    break
                }
            }
        }
        
        var openConnections: [Models.OpenConnection] = []
        for point in tile.connectionPoints {
            switch point {
            case .r0:
                if let topNeighbor = foundNeighbors[0] {
                    if !topNeighbor.connectionPoints.contains(.r180) {
                        openConnections.append(.init(position: tile.position, connectionPoint: .r0))
                    }
                } else {
                    // If there's no neighbor, it's always an open connection
                    openConnections.append(.init(position: tile.position, connectionPoint: .r0))
                }
            case .r90:
                if let rightNeighbor = foundNeighbors[1] {
                    if !rightNeighbor.connectionPoints.contains(.r270) {
                        openConnections.append(.init(position: tile.position, connectionPoint: .r90))
                    }
                } else {
                    // If there's no neighbor, it's always an open connection
                    openConnections.append(.init(position: tile.position, connectionPoint: .r90))
                }
            case .r180:
                if let bottomNeighbor = foundNeighbors[2] {
                    if !bottomNeighbor.connectionPoints.contains(.r0) {
                        openConnections.append(.init(position: tile.position, connectionPoint: .r180))
                    }
                } else {
                    // If there's no neighbor, it's always an open connection
                    openConnections.append(.init(position: tile.position, connectionPoint: .r180))
                }
            case .r270:
                if let leftNeighbor = foundNeighbors[3] {
                    if !leftNeighbor.connectionPoints.contains(.r90) {
                        openConnections.append(.init(position: tile.position, connectionPoint: .r270))
                    }
                } else {
                    // If there's no neighbor, it's always an open connection
                    openConnections.append(.init(position: tile.position, connectionPoint: .r270))
                }
            }
        }
        
        return openConnections
    }
} 
