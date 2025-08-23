//
//  ContentView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RecordView()
                .tabItem {
                    Image(systemName: "mic.circle.fill")
                    Text("Record")
                }
            
            MemosView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Memos")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MemoStore())
}
