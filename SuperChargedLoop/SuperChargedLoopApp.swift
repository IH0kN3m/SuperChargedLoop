//
//  SuperChargedLoopApp.swift
//  SuperChargedLoop
//
//  Created by Michael Myers on 3/30/25.
//

import SwiftUI

/// The main entry point for the SuperChargedLoop app.
@main
struct SuperChargedLoopApp: App {
    /// The main scene for the app, displaying the ContentView with its ViewModel.
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: ViewModel())
        }
    }
}
