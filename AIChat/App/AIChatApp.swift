//
//  AIChatApp.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//

import SwiftUI

@main
struct AIChatApp: App {

    /// Built once for the app's lifetime. The composition root.
    @State private var dependencies = AppDependencies.makeDefault()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                // Minimum size guard: sidebar + chat stays usable.
                .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 1000, height: 680)
        .windowResizability(.contentMinSize)
    }
}
