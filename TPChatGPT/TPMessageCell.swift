//
//  MessageCell.swift
//  TPChatGPT
//
//  Created by Thang Phung on 07/02/2023.
//

import Foundation
import SwiftUI
import Highlightr

struct MessageCell: View {
    @State private var cachingContentSize: CGSize?
    @ObservedObject private var vm: TPMessageCellViewModel
    
    #if os(macOS)
    private let paddingBubble: CGFloat = 30
    #else
    private let paddingBubble: CGFloat = 20
    #endif
    
    var contentHeightChangedAction: ((CGSize) -> Void)? = nil
    
    init(messageViewModel: TPMessageCellViewModel, contentHeightChangedAction: ((CGSize) -> Void)? = nil) {
        self.vm = messageViewModel
        self.contentHeightChangedAction = contentHeightChangedAction
    }
    
    var body: some View {
        VStack(spacing: 4, content: {
            if vm.message.data.isUser {
                Text(vm.message.data.text)
                    .textSelection(.enabled)
                    .padding()
                    .background(vm.message.data.isUser ? Color(hex: 0xb3ccff) : .green)
                    #if os(iOS)
                    .cornerRadius(radius: 10.0, corners: vm.message.data.isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                    #else
                    .cornerRadius(10)
                    #endif
            }
            else {
                VStack(alignment: .leading) {
                    ForEach(vm.messageDatas) { item in
                        if item.type == .plainText {
                            Text(item.getHighlightrMessage())
                                .textSelection(.enabled)
                        }
                        else {
                            Text(item.getHighlightrMessage())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(hex: 0x2f1e2e))
                                .cornerRadius(4)
                        }
                    }
                    .measureSize { size in
                        if let cachingContentSize = cachingContentSize,
                            size.height > cachingContentSize.height,
                           !vm.isRendered {
                            contentHeightChangedAction?(size)
                        }
                        
                        cachingContentSize = size
                    }
                }
                .padding()
                .background(vm.message.data.isUser ? Color(hex: 0xb3ccff) : .green)
                #if os(iOS)
                .cornerRadius(radius: 10.0, corners: vm.message.data.isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                #else
                .cornerRadius(10)
                #endif
            }
        })
        .shadow(color: Color.gray.opacity(0.5), radius: 5)
        .frame(maxWidth: .infinity, alignment: vm.message.data.isUser ? .trailing : .leading)
        .padding(EdgeInsets(top: 0,
                            leading: vm.message.data.isUser ? paddingBubble : 0,
                            bottom: 0,
                            trailing: !vm.message.data.isUser ? paddingBubble : 0))
    }
    
    
}

struct MessageCell_Previews: PreviewProvider {
    static var previews: some View {
        MessageCell(messageViewModel: TPMessageCellViewModel(message: TPMessage(data: TPUserMessage(text: "This is a code ````let a = 42````", created: Date.now))))
    }
}
