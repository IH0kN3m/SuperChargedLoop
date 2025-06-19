//
//  MatrixEngine.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 3/31/25.
//

import Foundation

/// Engine responsible for generating, mirroring, and updating the tile matrix for SuperChargedLoop.
class MatrixEngine {
    /// Generates a solvable matrix of tiles.
    ///
    /// Optionally, the caller can request the matrix to be mirrored across the **vertical** axis (`mirrorHoriz`) and/or
    /// across the **horizontal** axis (`mirrorVert`).
    /// When a mirroring option is enabled the engine will only create the tiles for the first half along the requested
    /// axis (or axes) and will automatically reflect them to the other side, making sure the tile orientation is also
    /// mirrored to preserve a valid solution.
    ///
    /// - Parameters:
    ///   - matrixSize: Tuple **(columns, rows)** specifying the desired size.
    ///   - mirrorHoriz: When `true`, the right-hand side of the matrix is a horizontal mirror of the left-hand side.
    ///   - mirrorVert:  When `true`, the bottom half of the matrix is a vertical mirror of the top half.
    /// - Returns: A tuple containing the generated grid and a list of open connections.
    func generateGrid(
        matrixSize: (Int, Int),
        mirrorHoriz: Bool = false,
        mirrorVert: Bool = false
    ) -> (grid: [[Models.Tile]], openConnections: [Models.OpenConnection]) {
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
                    // In the rare event that we hit a dead-end, start over with the same parameters.
                    return generateGrid(
                        matrixSize: matrixSize,
                        mirrorHoriz: mirrorHoriz,
                        mirrorVert: mirrorVert
                    )
                }
                
                row.append(candidates.randomElement() ?? .init())
            }
            grid.append(row)
        }
        
        // If requested, create a mirrored version of the grid **before** we apply the random rotations.
        let mirroredGrid: [[Models.Tile]]
        if mirrorHoriz || mirrorVert {
            mirroredGrid = makeMirroredGrid(
                from: grid,
                mirrorHoriz: mirrorHoriz,
                mirrorVert: mirrorVert
            )
        } else {
            mirroredGrid = grid
        }

        let shuffledResult = shuffleTilesWithRandomRotations(grid: mirroredGrid)
        return (grid: shuffledResult.grid, openConnections: shuffledResult.openConnections)
    }
    
    /// Rotates a tile at the given position in the grid and updates open connections.
    /// - Parameters:
    ///   - position: The position of the tile to rotate.
    ///   - grid: The current grid of tiles.
    ///   - openConnections: The current list of open connections.
    /// - Returns: The updated grid and open connections.
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
    
    /// Randomly rotates all tiles in the grid and recalculates open connections.
    /// - Parameter grid: The grid to shuffle and rotate.
    /// - Returns: The updated grid and open connections.
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
    
    /// Checks for open connections on a tile given its neighbors.
    /// - Parameters:
    ///   - tile: The tile to check.
    ///   - neighbors: The neighboring tiles.
    /// - Returns: An array of open connections for the tile.
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
    
    /// Re-evaluates the open-connection map for a tapped tile and its neighbors without performing the rotation.
    /// - Parameters:
    ///   - position: The position of the tile.
    ///   - grid: The current grid of tiles.
    ///   - openConnections: The current list of open connections.
    /// - Returns: The updated grid and open connections.
    func recalculateConnections(
        for position: Models.Position,
        in grid: [[Models.Tile]],
        openConnections: [Models.OpenConnection]
    ) -> (grid: [[Models.Tile]], openConnections: [Models.OpenConnection]) {
        let updatedGrid = grid // grid already contains the rotated tile
        var updatedOpenConnections = openConnections

        // Gather neighbours around the tapped tile
        var neighbours: [Models.Tile] = []
        if position.x > 0 { neighbours.append(updatedGrid[position.y][position.x - 1]) }
        if position.x < updatedGrid[position.y].count - 1 { neighbours.append(updatedGrid[position.y][position.x + 1]) }
        if position.y > 0 { neighbours.append(updatedGrid[position.y - 1][position.x]) }
        if position.y < updatedGrid.count - 1 { neighbours.append(updatedGrid[position.y + 1][position.x]) }

        let affectedTiles = [updatedGrid[position.y][position.x]] + neighbours
        let affectedPositions = affectedTiles.map { $0.position }

        // Purge any previous open-connection records for the affected tiles
        updatedOpenConnections.removeAll { affectedPositions.contains($0.position) }

        // Re-calculate connections only for the affected tiles
        for tile in affectedTiles {
            var tileNeighbours: [Models.Tile] = []
            if tile.position.x > 0 { tileNeighbours.append(updatedGrid[tile.position.y][tile.position.x - 1]) }
            if tile.position.x < updatedGrid[tile.position.y].count - 1 { tileNeighbours.append(updatedGrid[tile.position.y][tile.position.x + 1]) }
            if tile.position.y > 0 { tileNeighbours.append(updatedGrid[tile.position.y - 1][tile.position.x]) }
            if tile.position.y < updatedGrid.count - 1 { tileNeighbours.append(updatedGrid[tile.position.y + 1][tile.position.x]) }

            updatedOpenConnections.append(contentsOf: checkOpenConnections(of: tile, with: tileNeighbours))
        }

        return (grid: updatedGrid, openConnections: updatedOpenConnections)
    }

    // MARK: - Mirroring helpers

    /// Produces a new grid by mirroring the `source` grid according to the requested axes.
    /// - Parameters:
    ///   - source: The original grid to mirror.
    ///   - mirrorHoriz: Whether to mirror horizontally.
    ///   - mirrorVert: Whether to mirror vertically.
    /// - Returns: The mirrored grid.
    private func makeMirroredGrid(
        from source: [[Models.Tile]],
        mirrorHoriz: Bool,
        mirrorVert: Bool
    ) -> [[Models.Tile]] {
        guard let firstRow = source.first else { return source }
        let columns = firstRow.count
        let rows = source.count

        var result: [[Models.Tile]] = Array(
            repeating: Array(repeating: Models.Tile(), count: columns),
            count: rows
        )

        for y in 0..<rows {
            for x in 0..<columns {
                var srcX = x
                var srcY = y
                var applyHoriz = false
                var applyVert = false

                if mirrorHoriz && x >= (columns + 1) / 2 {
                    srcX = columns - 1 - x
                    applyHoriz = true
                }

                if mirrorVert && y >= (rows + 1) / 2 {
                    srcY = rows - 1 - y
                    applyVert = true
                }

                let originalTile = source[srcY][srcX]
                let newPosition = Models.Position(x: x, y: y)

                if applyHoriz || applyVert {
                    // Create a brand-new tile with the mirrored orientation.
                    let mirroredRotation = mirroredRotation(
                        for: originalTile.rotation,
                        mirrorHoriz: applyHoriz,
                        mirrorVert: applyVert
                    )
                    result[y][x] = Models.Tile(
                        type: originalTile.type,
                        position: newPosition,
                        rotation: mirroredRotation
                    )
                } else {
                    // Re-use the existing tile when no transformation is needed.
                    result[y][x] = originalTile
                }
            }
        }

        return result
    }

    /// Returns the rotation that results from mirroring a rotation horizontally, vertically, or both.
    /// - Parameters:
    ///   - rotation: The original rotation.
    ///   - mirrorHoriz: Whether to mirror horizontally.
    ///   - mirrorVert: Whether to mirror vertically.
    /// - Returns: The mirrored rotation.
    private func mirroredRotation(
        for rotation: Models.RotationPoint,
        mirrorHoriz: Bool,
        mirrorVert: Bool
    ) -> Models.RotationPoint {
        var result = rotation

        if mirrorHoriz {
            result = switch result {
            case .r90: .r270
            case .r270: .r90
            default: result
            }
        }

        if mirrorVert {
            result = switch result {
            case .r0: .r180
            case .r180: .r0
            default: result
            }
        }

        return result
    }
} 
