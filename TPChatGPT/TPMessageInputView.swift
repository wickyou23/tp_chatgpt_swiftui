//
//  TPMessageInputView.swift
//  TPChatGPT
//
//  Created by Thang Phung on 17/02/2023.
//

import Foundation
import SwiftUI

struct TPMessageInputView: View {
    @EnvironmentObject private var gptManager: TPGPTManager
    @State private var inputTextField: String = ""
    @FocusState private var focusTextField: Bool
    
    var body: some View {
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
    }
    
    func sendButton() {
        guard !inputTextField.isEmpty else { return }
        gptManager.addStreamUserMessage(message: TPUserMessage(text: inputTextField, created: Date.now))
        inputTextField = ""
    }
}

struct TPMessageInputView_Previews: PreviewProvider {
    static var previews: some View {
        TPMessageInputView()
    }
}
