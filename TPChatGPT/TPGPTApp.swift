//
//  TPChatGPTApp.swift
//  TPChatGPT
//
//  Created by Thang Phung on 07/02/2023.
//

import SwiftUI

@main
struct TPGPTApp: App {
    @StateObject private var gptManager = TPGPTManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.colorScheme, .light)
                .environmentObject(gptManager)
        }
    }
}
