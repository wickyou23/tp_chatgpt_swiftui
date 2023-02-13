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
    @State private var inputTextField: String = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isShowError = false
    @FocusState private var focusTextField: Bool
    
    private let spacerId = "spacer_id"
    
    
    
    private var contentView: some View {
        VStack(spacing: 0, content: {
            ///bugs of List when use scroll proxy: https://developer.apple.com/forums/thread/712510
            ///for now: convert to lazyVStack (poor performance)
            ScrollViewReader { proxy in
                ZStack {
                    ScrollView {
                        LazyVStack {
                            Spacer()
                                .frame(height: 16)
                            
                            ForEach(gptManager.messages, id: \.id) { message in
                                MessageCell(message: message, contentHeightChangedAction: { size in
                                    scrollToBottom()
                                })
                                #if os(iOS)
                                .listRowSeparator(.hidden)
                                #endif
                                .id(message.id)
                            }
                            .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                            .onAppear {
                                scrollProxy = proxy
                            }
                            
                            Spacer()
                                .frame(height: 16)
                                .id(spacerId)
                        }
                        .onChange(of: gptManager.messages) { newValue in
                            scrollToBottom()
                        }
                    }
                    .background(Color(hex: 0xfefefe))
                    .listStyle(.plain)
                    #if os(iOS)
                    .scrollDismissesKeyboard(.interactively)
                    #endif
                    .onTapGesture {
                        focusTextField = false
                    }
                    
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
                                isShowError = e != nil
                            default:
                                isShowError = false
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
            }
            
            HStack(alignment: .center, content: {
                TextField("Type a question?", text: $inputTextField)
                    #if os(iOS)
                    .keyboardType(.default)
                    #endif
                    .focused($focusTextField)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    .keyboardShortcut(.defaultAction)
                    .onSubmit {
                        sendButton()
                    }
                    #endif
                
                if (!gptManager.streamState.isDone) {
                    TPGPTLoading()
                }
                else {
                    Button {
                        sendButton()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            #if os(iOS)
                            .font(.system(size: 20))
                            #endif
                            .foregroundColor(.blue)
                    }
                }
            })
            .padding()
            .background(Color(hex: 0xfafafa))
            .shadow(color: Color.gray.opacity(0.5), radius: 4)
        })
        .navigationTitle("GPT-3")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
    }
    
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
            .frame(minWidth: 600, minHeight: 400)
        #endif
    }
    
    func sendButton() {
        guard !inputTextField.isEmpty else { return }
        gptManager.addStreamUserMessage(message: TPUserMessage(text: inputTextField, created: Date.now))
        inputTextField = ""
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
