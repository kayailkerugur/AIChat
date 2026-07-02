//
//  AIChatApp.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//

import SwiftUI
import CoreData

@main
struct AIChatApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
