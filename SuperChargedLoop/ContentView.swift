//
//  ContentView.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 3/30/25.
//

import SwiftUI

/// The main view for the SuperChargedLoop app, displaying the interactive tile grid and settings.
struct ContentView: View {
    /// The view model managing the app's state and logic.
    @ObservedObject var viewModel: ViewModel
    /// Controls the presentation of the settings sheet.
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                HStack { Spacer() }
            }
            .background(viewModel.selectedColorPair.pastel.opacity(0.75))
            .ignoresSafeArea()

            if !viewModel.grid.isEmpty {
                Group {
                    if viewModel.requiresScroll {
                        ScrollView([.vertical, .horizontal]) { lazyGridBody }
                    } else { gridBody }
                }
            }
        }
        .statusBarHidden(true)
        .onAppear { Task { viewModel.generateGrid() } }
        .onChange(of: viewModel.openConnections) {
            if viewModel.openConnections.isEmpty {
               viewModel.generateGrid()
            }
        }
        .onTapGesture {
            if viewModel.tapBackgroundToRegenerate {
                viewModel.generateGrid()
            }
        }
        .overlay(alignment: .bottom) {
            Button(action: { showSettings = true }, label: {
                Text("...")
                    .foregroundColor(viewModel.selectedColorPair.darker)
                    .font(.system(size: 24, weight: .bold))
            })
        }
        .sheet(isPresented: $showSettings) {
            VStack(spacing: 24) {
                Text("Settings")
                    .font(.title2)
                    .bold()
                    .padding(.top)

                Picker("Level Density", selection: $viewModel.densityLevel) {
                    Text("Normal").tag(DensityLevel.normal)
                    Text("Dense").tag(DensityLevel.dense)
                    Text("Scrolling").tag(DensityLevel.scrolling)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                if viewModel.densityLevel == .scrolling {
                    VStack {
                        Stepper("Rows: \(viewModel.customRows)", value: $viewModel.customRows, in: 2...100)
                        Stepper("Columns: \(viewModel.customCols)", value: $viewModel.customCols, in: 2...100)
                    }
                    .padding(.horizontal)
                }

                Divider()

                Toggle("Haptic Feedback", isOn: $viewModel.hapticsEnabled)
                    .padding(.horizontal)

                Toggle("Tap background to regenerate", isOn: $viewModel.tapBackgroundToRegenerate)
                    .padding(.horizontal)

                Spacer()

                Button(action: {
                    viewModel.regenerateLevel()
                    showSettings = false
                }) {
                    Text("Regenerate Level")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(viewModel.selectedColorPair.pastel.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            .padding()
        }
    }

    /// A standard grid view for smaller matrices.
    var gridBody: some View {
        VStack(alignment: .center, spacing: 0) {
            ForEach(0..<viewModel.grid.count, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<viewModel.grid[row].count, id: \.self) { col in
                        let tile = viewModel.grid[row][col]
                        tileView(tile)
                    }
                }
            }
        }
        .compositingGroup()
        .shadow(color: viewModel.selectedColorPair.darker.opacity(0.35), radius: 4, x: 2, y: 2)
    }

    /// A lazy grid view for large, scrollable matrices.
    var lazyGridBody: some View {
        LazyVStack(alignment: .center, spacing: 0) {
            ForEach(0..<viewModel.grid.count, id: \.self) { row in
                LazyHStack(spacing: 0) {
                    ForEach(0..<viewModel.grid[row].count, id: \.self) { col in
                        let tile = viewModel.grid[row][col]
                        tileView(tile)
                    }
                }
            }
        }
        .compositingGroup()
        .shadow(color: viewModel.selectedColorPair.darker.opacity(0.35), radius: 4, x: 2, y: 2)
    }

    /// Returns a view for a single tile, handling its appearance and rotation gesture.
    /// - Parameter tile: The tile model to display.
    /// - Returns: A SwiftUI view representing the tile.
    func tileView(_ tile: Models.Tile) -> some View {
        tile.asset
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: viewModel.tileSize, height: viewModel.tileSize)
            .foregroundColor(.white)
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
