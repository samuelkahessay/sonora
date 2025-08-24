//
//  ContentView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RecordView()
                .tabItem {
                    Image(systemName: "mic.circle.fill")
                    Text("Record")
                }
                .tag(0)
            
            MemosView(popToRoot: popToRoot)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Memos")
                }
                .tag(1)
                .onTapGesture(count: 2) {
                    if selectedTab == 1 {
                        popToRoot()
                    }
                }
        }
    }
    
    private func popToRoot() {
        NotificationCenter.default.post(name: .popToRootMemos, object: nil)
    }
}

#Preview {
    ContentView()
        .environmentObject(MemoStore())
}
