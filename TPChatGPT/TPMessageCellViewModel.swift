//
//  TPMessageCellViewModel.swift
//  TPChatGPT
//
//  Created by Thang Phung on 17/02/2023.
//

import Foundation
import Combine
import SwiftUI

class TPMessageCellViewModel: NSObject, ObservableObject {
    @Published private(set) var messageDatas: [MessageCellData] = []
    
    private let gptManager = TPGPTManager.shared
    private(set) var message: TPMessage
    private var currentMessage: String = ""
    private let handleMessageOperationQueue = TPMessageHandlerOperationQueue()
    private var subscriptions: [AnyCancellable?] = []
    
    private(set) var isRendered = false
    private var cachingRenderedMessages: [MessageCellData] = []
    
    deinit {
        debugPrint("TPMessageCellViewModel deinit ===")
    }
    
    init(message: TPMessage) {
        self.message = message
        super.init()
        subscriptions.append(self.message.data.textPublisher.sink {
            [weak self] newValue in
            self?.handleMessage(newTextMessage: newValue)
        })
        
        handleMessageOperationQueue.finishedAllOperations = {
            [weak self] in
            guard let self = self else { return }

            debugPrint("handleMessageOperationQueue \(self.gptManager.streamState)")
            guard self.gptManager.streamState.isDone else {
                self.isRendered = false
                return
            }

            self.isRendered = true
            self.subscriptions.forEach({ $0?.cancel() })
            self.subscriptions = []
        }
        
        subscriptions.append(gptManager.$streamState.sink {
            [weak self] newValue in
            guard let self = self else { return }
            debugPrint("[gptManager.$streamState]: \(newValue.isDone) \(self.handleMessageOperationQueue.isFinished)")
            if newValue.isDone && self.handleMessageOperationQueue.isFinished {
                self.isRendered = true
                self.subscriptions.forEach({ $0?.cancel() })
                self.subscriptions = []
            }
        })
    }
    
    private func handleMessage(newTextMessage: String) {
//        debugPrint("handleMessage [MESSAGE][\(newTextMessage.count)]: \(newTextMessage)")
        guard currentMessage != newTextMessage else {
            debugPrint("currentMessage and newTextMessage is the same")
            self.isRendered = true
            return
        }
        
        self.isRendered = false
        currentMessage = newTextMessage
        handleMessageOperationQueue.addOperation(BlockOperation {
            [weak self] in
            self?._handleMessage(textMessage: newTextMessage)
        })
    }
    
    private func _handleMessage(textMessage: String) {
//        debugPrint("_handleMessage [MESSAGE][\(textMessage.count)]: \(textMessage)")
        
        var newMessageDatas = Array(cachingRenderedMessages)
        let nsmessage = NSString(string: textMessage)
        
        var last4: String
        if nsmessage.length < 4 {
            last4 = textMessage
        }
        else {
            last4 = nsmessage.substring(with: NSRange(location: nsmessage.length - 4, length: 4))
        }
        
        if last4 == "````" {
            if newMessageDatas.isEmpty {
                debugPrint("[LAST 4][EMPTY]: \(last4)")
                newMessageDatas.append(MessageCellData(message: "",
                                                       type: .code,
                                                       startAt: nsmessage.length,
                                                       endAt: nsmessage.length))
            }
            else {
                let lastData = newMessageDatas.last!
                debugPrint("[LAST 4][NOEMPTY][\(lastData.type)][\(lastData.message)]: \(last4)")
                if lastData.type == .plainText {
                    newMessageDatas.append(MessageCellData(message: "",
                                                           type: .code,
                                                           startAt: nsmessage.length,
                                                           endAt: nsmessage.length))
                }
                else {
                    newMessageDatas.append(MessageCellData(message: "",
                                                           type: .plainText,
                                                           startAt: nsmessage.length,
                                                           endAt: nsmessage.length))
                }
            }
        }
        else {
            if newMessageDatas.isEmpty {
                guard nsmessage.length != 0 else {
                    return
                }
                
                newMessageDatas.append(MessageCellData(message: String(nsmessage),
                                                       type: .plainText,
                                                       startAt: 0,
                                                       endAt: nsmessage.length))
            }
            else {
                var lastData = newMessageDatas.removeLast()
                let nextMessage = nsmessage.substring(with: NSRange(location: lastData.endAt, length: max(0, nsmessage.length - lastData.endAt)))
                var moreMsg = lastData.message
                if lastData.message.isEmpty && lastData.type == .code {
                    moreMsg += NSString(string: nextMessage).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                else {
                    moreMsg += nextMessage
                }
                
                lastData = MessageCellData(message: moreMsg,
                                           type: lastData.type,
                                           startAt: lastData.startAt,
                                           endAt: nsmessage.length)
                newMessageDatas.append(lastData)
            }
        }
        
        cachingRenderedMessages = newMessageDatas
        DispatchQueue.main.async {
            [weak self] in
            self?.messageDatas = self?.cachingRenderedMessages ?? []
        }
    }
}

enum MessageCellDataType {
    case plainText, code
}

struct MessageCellData: Identifiable {
    let id: String = UUID().uuidString
    let message: String
    let type: MessageCellDataType
    let startAt: Int
    let endAt: Int
    
    private var highlightrMessage: AttributedString?
    
    init(message: String, type: MessageCellDataType, startAt: Int, endAt: Int) {
        self.message = message
        self.type = type
        self.startAt = startAt
        self.endAt = endAt
        
        if type == .code {
            highlightrMessage = TPGPTHelper.handleCodeHighlightr(message: message)
        }
        else {
            highlightrMessage = TPGPTHelper.handleMarkdownHighlightr(message: message)
        }
        
        debugPrint("MessageCellData: highlight on \(Thread.isMainThread ? "Main" : "Background") Thread")
    }
    
    func getHighlightrMessage() -> AttributedString {
        return highlightrMessage ?? AttributedString(message)
    }
}

private class TPMessageHandlerOperationQueue: OperationQueue {
    var finishedAllOperations: (() -> Void)?
    var isFinished: Bool {
        return numberOperation == 0
    }
    
    private var numberOperation: Int = 0 {
        didSet {
            debugPrint("numberOperation: \(numberOperation)")
            guard numberOperation == 0 else {
                return
            }
            
            finishedAllOperations?()
        }
    }
    
    override init() {
        super.init()
        maxConcurrentOperationCount = 1
        qualityOfService = .background
    }
    
    override func addOperation(_ op: Operation) {
        let opCompletion = op.completionBlock
        op.completionBlock = {
            [weak self] in
            opCompletion?()
            
            guard let self = self else {
                debugPrint("TPMessageHandlerOperationQueue deinit ===============")
                return
            }
            
            self.numberOperation -= 1
        }
        
        numberOperation += 1
        super.addOperation(op)
    }
}
