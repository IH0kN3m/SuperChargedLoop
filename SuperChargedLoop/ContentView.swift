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
        ZStack {
            VStack {
                Spacer()
                HStack { Spacer() }
            }.background(viewModel.selectedColorPair.pastel.opacity(0.25))

            if !viewModel.grid.isEmpty {
                VStack(alignment: .center, spacing: 0) {
                    ForEach(0..<viewModel.grid.count, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<viewModel.grid[row].count, id: \.self) { col in
                                let tile = viewModel.grid[row][col]

                                tile.asset
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                    .foregroundColor(viewModel.selectedColorPair.darker)
                                    .rotationEffect(.degrees(Double(tile.rotationCount) * 90))
                                    .animation(.interpolatingSpring(duration: 0.20, bounce: 0.25), value: tile.rotationCount)
                                    .simultaneousGesture(
                                        LongPressGesture(minimumDuration: 0.01)
                                            .onEnded { _ in 
                                                viewModel.rotateElement(at: tile.position) 
                                            }
                                    )
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .onAppear { Task { viewModel.generateGrid() } }
        .onChange(of: viewModel.openConnections) {
            if viewModel.openConnections.isEmpty { viewModel.generateGrid() }
        }
    }
}
