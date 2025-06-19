//
//  ContentView.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 3/30/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = ViewModel()
    
    let selectedColorPair: (pastel: Color, darker: Color) = {
        let pairs = [
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
        return pairs.randomElement() ?? (
            Color(red: 0.7, green: 0.8, blue: 1.0), Color(red: 0.5, green: 0.6, blue: 0.8)
        )
    }()

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack { Spacer() }
            }.background(selectedColorPair.pastel.opacity(0.25))

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
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(selectedColorPair.darker)
                                    .rotationEffect(.degrees(Double(tile.rotationCount) * 90))
                                    .animation(.easeInOut(duration: 0.1), value: tile.rotationCount)
                                    .onTapGesture { viewModel.rotateElement(at: tile.position) }
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { Task { viewModel.generateGrid() } }
        .onChange(of: viewModel.openConnections) {
            if viewModel.openConnections.isEmpty { viewModel.generateGrid() }
        }
    }
}
