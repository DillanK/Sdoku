//
//  ContentView.swift
//  Sdoku
//
//  Created by hyunjin on 4/9/26.
//

import SwiftUI
import CoreData

/// 앱 루트 뷰 — HomeView 래퍼
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        HomeView(viewModel: HomeViewModel(repository: GameRecordRepository(context: viewContext)))
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
