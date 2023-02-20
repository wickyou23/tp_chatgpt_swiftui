//
//  ContentView.swift
//  TPChatGPT
//
//  Created by Thang Phung on 07/02/2023.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var gptManager: TPGPTManager
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isShowError = false
    
    private let spacerId = "spacer_id"
    
    private var contentView: some View {
        VStack(spacing: 0, content: {
            ZStack {
                TPMessageListView()
                
                VStack {
                    Spacer()
                    
                    if isShowError {
                        Text("Sorry, an error ocurred. Please try again.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.red)
                            .shadow(color: Color.gray.opacity(0.5), radius: 4)
                            .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
                    }
                }
                .onReceive(gptManager.$streamState) { newValue in
                    withAnimation {
                        switch newValue {
                        case .done(let e):
                            let isError = e != nil
                            if isError != isShowError {
                                isShowError = isError
                            }
                        default:
                            if isShowError != false {
                                isShowError = false
                            }
                        }
                    }
                    
                    if isShowError {
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2) {
                            withAnimation {
                                isShowError.toggle()
                            }
                        }
                    }
                }
            }
            
            ///Why move textfield to outside?
            ///https://developer.apple.com/forums/thread/120710
            TPMessageInputView()
        })
        .navigationTitle("GPT-3")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
    }
    
    @State private var source = "let a = 42\n"
    
    var body: some View {
        #if os(iOS)
        NavigationView {
           contentView
        }
        .environment(\.horizontalSizeClass, .compact)
        .onReceive(keyboardPublisher) { value in
            if value {
                scrollToBottom()
            }
        }
        #else
        contentView
            .frame(minWidth: 600, minHeight: 600)
        #endif
    }
    
    func sendButtonDump() {
        gptManager.addUserMessageDump(message: TPUserMessage(text: "Hello, Welcome to TPChatGPT", created: Date.now))
    }
    
    func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.15) {
            withAnimation {
                scrollProxy?.scrollTo(spacerId, anchor: .bottom)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.colorScheme, .light)
            .environmentObject(TPGPTManager())
    }
}
