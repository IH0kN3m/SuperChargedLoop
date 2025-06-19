//
//  ContentView.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 3/30/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ViewModel()

    var body: some View {
        VStack {
            if !viewModel.grid.isEmpty {
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .center, spacing: 0) {
                        ForEach(0..<viewModel.grid.count, id: \.self) { row in
                            LazyHStack(spacing: 0) {
                                ForEach(0..<viewModel.grid[row].count, id: \.self) { col in
                                    let tile = viewModel.grid[row][col]
                                    
                                    tile.asset
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .rotationEffect(.degrees(Double(tile.rotationCount) * 90))
                                        .animation(.easeInOut(duration: 0.3), value: tile.rotationCount)
                                        .onTapGesture { 
                                            viewModel.rotateElement(at: tile.position) 
                                        }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }

            Text("Matrix: \(viewModel.grid.count)x\(viewModel.grid.first?.count ?? 0)")
            Text("Mismatches: \(viewModel.openConnections.count)")
            Button(action: { viewModel.generateGrid() }, label: { Text("Regenerate") })
        }
        .onAppear { Task { viewModel.generateGrid() } }
    }
}

class ViewModel: ObservableObject {
    private let matrixEngine = MatrixEngine(matrixSize: (10, 15))

    @Published
    @MainActor
    var grid: [[Models.Tile]] = []

    @Published
    @MainActor
    var openConnections: [Models.OpenConnection] = []

    func generateGrid() {
        Task {
            let result = matrixEngine.generateGrid()
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
