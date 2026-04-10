//
//  SdokuApp.swift
//  Sdoku
//
//  Created by hyunjin on 4/9/26.
//

import SwiftUI
import CoreData

@main
struct SdokuApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            GameView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
