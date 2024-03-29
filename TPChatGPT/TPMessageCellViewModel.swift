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
    @Published private(set) var messageDatas: [TPMessageCellData] = []
    
    private let gptManager = TPGPTManager.shared
    private(set) var message: TPMessage
    private var currentMessage: String = ""
    private let handleMessageOperationQueue = TPMessageHandlerOperationQueue()
    private var subscriptions = Set<AnyCancellable>()
    
    private(set) var isRendered = false
    private var cachingRenderedMessages: [TPMessageCellData] = []
    
    deinit {
        debugPrint("TPMessageCellViewModel deinit ===")
    }
    
    init(message: TPMessage) {
        self.message = message
        super.init()
        self.message.data.textPublisher.sink {
            [weak self] newValue in
            self?.handleMessage(newTextMessage: newValue)
        }.store(in: &subscriptions)
        
        handleMessageOperationQueue.finishedAllOperations = {
            [weak self] in
            guard let self = self else { return }
            
            guard self.gptManager.streamState.isDone else {
                self.isRendered = false
                return
            }
            
            debugPrint("handleMessageOperationQueue \(self.gptManager.streamState)")
            self.isRendered = true
            self.subscriptions.forEach({ $0.cancel() })
            self.subscriptions.removeAll()
        }
        
        gptManager.$streamState.sink {
            [weak self] newValue in
            guard let self = self else { return }
            guard newValue.isDone && self.handleMessageOperationQueue.isFinished else {
                return
            }
            
            debugPrint("[gptManager.$streamState]: \(newValue.isDone) \(self.handleMessageOperationQueue.isFinished)")
            self.isRendered = true
            self.subscriptions.forEach({ $0.cancel() })
            self.subscriptions.removeAll()
        }
        .store(in: &subscriptions)
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
        
        var last3: String
        if nsmessage.length < 3 {
            last3 = textMessage
        }
        else {
            last3 = nsmessage.substring(with: NSRange(location: nsmessage.length - 3, length: 3))
        }
        
        ///the solution had predicated, please double check to response of new api
        if last3 == "```" {
            if newMessageDatas.isEmpty {
                debugPrint("[LAST 3[EMPTY]: \(last3)")
                newMessageDatas.append(TPMessageCellData(message: "",
                                                         type: .code,
                                                         startAt: nsmessage.length,
                                                         endAt: nsmessage.length))
            }
            else {
                let lastData = newMessageDatas.last!
                debugPrint("[LAST 3][NOEMPTY][\(lastData.type)][\(lastData.message)]: \(last3)")
                if lastData.type == .plainText {
                    newMessageDatas.append(TPMessageCellData(message: "",
                                                             type: .code,
                                                             startAt: nsmessage.length,
                                                             endAt: nsmessage.length))
                }
                else {
                    newMessageDatas.append(TPMessageCellData(message: "",
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
                
                newMessageDatas.append(TPMessageCellData(message: String(nsmessage),
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
                
                lastData = TPMessageCellData(message: moreMsg,
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

enum TPMessageCellDataType {
    case plainText, code
}

struct TPMessageCellData: Identifiable {
    let id: String = UUID().uuidString
    let message: String
    let type: TPMessageCellDataType
    let startAt: Int
    let endAt: Int
    
    private var highlightrMessage: AttributedString?
    
    init(message: String, type: TPMessageCellDataType, startAt: Int, endAt: Int) {
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
