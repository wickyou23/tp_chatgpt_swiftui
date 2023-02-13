//
//  MessageCell.swift
//  TPChatGPT
//
//  Created by Thang Phung on 07/02/2023.
//

import Foundation
import SwiftUI

struct MessageCell: View {
    @State private var currentMessage: String = ""
    @State private var cachingContentSize: CGSize?
    
    var message: TPMessage
    var contentHeightChangedAction: ((CGSize) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 4, content: {
            Text(currentMessage)
                .textSelection(.enabled)
                .padding()
                .background(message.data.isUser ? Color(hex: 0xb3ccff) : .green)
                #if os(iOS)
                .cornerRadius(radius: 10.0, corners: message.data.isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                #else
                .cornerRadius(10)
                #endif
                .onReceive(message.data.textPublisher) { newText in
                    currentMessage = newText
                }
                .measureSize { size in
                    if let cachingContentSize = cachingContentSize, size.height > cachingContentSize.height {
                        contentHeightChangedAction?(size)
                    }
                    
                    cachingContentSize = size
                    
                }
        })
        .shadow(color: Color.gray.opacity(0.5), radius: 5)
        .frame(maxWidth: .infinity, alignment: message.data.isUser ? .trailing : .leading)
        .padding(EdgeInsets(top: 0,
                            leading: message.data.isUser ? 20 : 0,
                            bottom: 0,
                            trailing: !message.data.isUser ? 20 : 0))
    }
}

struct MessageCell_Previews: PreviewProvider {
    static var previews: some View {
        MessageCell(message: TPMessage(data: TPUserMessage(text: "Hello my GPT", created: Date.now)))
    }
}
