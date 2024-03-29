//
//  ChatGPTManager.swift
//  TPChatGPT
//
//  Created by Thang Phung on 07/02/2023.
//

import Foundation
import Combine

private let API_KEY = "<API KEY>"
private let DEFAULT_HEADER = ["Content-Type": "application/json", "Authorization": API_KEY]

enum TPGPTManagerState {
    case sending
    case reading
    case done(Error?)
    
    var isReading: Bool {
        switch self {
        case .reading:
            return true
        default:
            return false
        }
    }
    
    var isDone: Bool {
        switch self {
        case .done(_):
            return true
        default:
            return false
        }
    }
}

class TPGPTManager: NSObject, ObservableObject {
    static let shared = TPGPTManager()
    
    @Published var streamState: TPGPTManagerState = .done(nil)
    @Published var messages: [TPMessage] = []
    @Published var dumpMessages: [TPMessage] = [
        TPMessage(data: TPUserMessage(text: "Hello, Welcome to TPChatGPT", created: Date.now)),
        TPMessage(data: TPUserMessage(text: "This is a text", created: Date.now)),
        TPMessage(data: TPUserMessage(text: "What are you doing?", created: Date.now)),
        TPMessage(data: TPUserMessage(text: "Are you OK?", created: Date.now)),
    ]
    
    private let urlSession: URLSession
    private var urlSessionStream: URLSession!
    private var operationQueue: OperationQueue
    
    override init() {
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        
        urlSession = URLSession(configuration: .default)
        
        super.init()
        urlSessionStream = URLSession(configuration: .default, delegate: self, delegateQueue: operationQueue)
    }
    
    func addStreamUserMessage(message: TPUserMessage) {
        messages.append(TPMessage(data: message))
        let modifyMsg = message.text
        sendStreamMessageToGPT(prompt: modifyMsg)
    }
    
    func addUserMessageDump(message: TPUserMessage) {
        messages.append(TPMessage(data: message))
    }
    
    private func sendStreamMessageToGPT(prompt: String) {
        let bodyJS: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.7,
            "max_tokens": 2048,
            "stop": ["\n\n\n"],
            "stream": true
        ]
        
        guard let dataJS = try? JSONSerialization.data(withJSONObject: bodyJS) else {
            return
        }
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.httpBody = dataJS
        request.allHTTPHeaderFields = DEFAULT_HEADER
        
        streamState = .sending
        urlSessionStream.dataTask(with: request).resume()
    }
}

extension TPGPTManager: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if !streamState.isReading {
            DispatchQueue.main.async {
                self.streamState = .reading
            }
        }
        
        if let error = dataTask.error {
            print("[ERROR]: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.streamState = .done(NSError(domain: "[ERROR]: \(error.localizedDescription)", code: -1))
            }
            return
        }
        
        guard var str = String(data: data, encoding: .utf8) else {
            print("[ERROR]: cannot convert stream data to string")
            DispatchQueue.main.async {
                self.streamState = .done(NSError(domain: "[ERROR]: cannot convert stream data to string", code: -1))
            }
            return
        }
        
        str = NSString(string: str).trimmingCharacters(in: .whitespacesAndNewlines)
        let allText = NSString(string: str).components(separatedBy: "data: ")
        var newestGPTMessage: TPGPTMessage?
        var newestChunkMsg = ""
        for str in allText {
            if str.isEmpty {
                continue
            }
            
            if str == "[DONE]" {
                DispatchQueue.main.async {
                    debugPrint("Stream message [DONE] ==========")
                    self.streamState = .done(nil)
                }
                
                return
            }
            
            let decoder = JSONDecoder()
            guard let trimData = str.data(using: .utf8) else {
                print("[ERROR]: cannot convert stream data to JSON")
                DispatchQueue.main.async {
                    self.streamState = .done(NSError(domain: "[ERROR]: cannot convert stream data to string", code: -1))
                }
                return
            }
            
            do {
                newestGPTMessage = try decoder.decode(TPGPTMessage.self, from: trimData)
                newestChunkMsg += newestGPTMessage!.text
            } catch {
                print("[ERROR]: \(error.localizedDescription):\(str)")
                DispatchQueue.main.async {
                    self.streamState = .done(NSError(domain: "[ERROR]: \(error.localizedDescription):\(str)", code: -1))
                }
                
                return
            }
        }
        
//        print("[CHUNK] \(newestChunkMsg)")
        guard let newestGPTMessage = newestGPTMessage else {
            DispatchQueue.main.async {
                self.streamState = .done(NSError(domain: "[ERROR]: Unknown error", code: -1))
            }
            return
        }
        
        if let lastMsg = messages.last,
           lastMsg.dataId == newestGPTMessage.id {
            guard let preGPTMsg = lastMsg.data as? TPGPTMessage else {
                DispatchQueue.main.async {
                    self.streamState = .done(NSError(domain: "[ERROR]: Unknown error", code: -1))
                }
                return
            }

            let newText = preGPTMsg.choice!.text + newestChunkMsg
            preGPTMsg.updateNewText(newText: newText)
        }
        else {
            newestGPTMessage.updateNewText(newText: newestChunkMsg)
            DispatchQueue.main.async {
                self.messages.append(TPMessage(data: newestGPTMessage))
            }
        }
    }
}
