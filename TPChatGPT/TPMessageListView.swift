//
//  TPMessageListView.swift
//  TPChatGPT
//
//  Created by Thang Phung on 17/02/2023.
//

import Foundation
import SwiftUI
import Combine

struct TPMessageListView: View {
    @EnvironmentObject private var gptManager: TPGPTManager
    @State private var messageVMs: [TPMessageCellViewModel] = []
    @State var scrollProxy: ScrollViewProxy!
    
    private let spacerId = "spacer_id"
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ///bugs of List when use scroll proxy: https://developer.apple.com/forums/thread/712510
                ///for now: convert to lazyVStack (poor performance)
                LazyVStack {
                    Spacer()
                        .frame(height: 16)
                    
                    ForEach(messageVMs, id: \.message.id) { messageVM in
                        TPMessageCell(messageViewModel: messageVM, contentHeightChangedAction: { size in
                            scrollToBottom()
                        })
                        #if os(iOS)
                        .listRowSeparator(.hidden)
                        #endif
                        .id(messageVM.message.id)
                    }
                    .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                    .onReceive(gptManager.$messages) { newValue in
                        guard let last = newValue.last else {
                            return
                        }
                        
                        let lastVM = messageVMs.last
                        if lastVM == nil || last.id != lastVM?.message.id {
                            messageVMs.append(TPMessageCellViewModel(message: last))
                        }
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
                #if os(iOS)
                hideKeyboard()
                #endif
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
    }
    
    func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.15) {
            withAnimation {
                scrollProxy?.scrollTo(spacerId, anchor: .bottom)
            }
        }
    }
}
