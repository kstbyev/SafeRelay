//
//  SafeRelayApp.swift
//  SafeRelay
//
//  Created by Madi Sharipov on 21.04.2025.
//

import SwiftUI 

@main
struct SafeRelayApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
