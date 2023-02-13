//
//  Message.swift
//  TPChatGPT
//
//  Created by Thang Phung on 07/02/2023.
//

import Foundation
import SwiftUI

protocol IMessage {
    var id: String { get set }
    var created: Date { get set }
    var isUser: Bool { get }
    var text: String { get set }
    var textPublisher: Published<String>.Publisher { get }
}

class TPUserMessage: IMessage, Codable, Identifiable {
    @Published var text: String
    var textPublisher: Published<String>.Publisher { $text }
    
    var id: String
    var created: Date
    var isUser: Bool {
        return true
    }
    
    init(text: String, created: Date) {
        self.id = UUID().uuidString
        self.text = text
        self.created = created
    }
    
    func getMessages() -> [String] {
        return [text]
    }
    
    enum CodingKeys: CodingKey {
        case id
        case text
        case created
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        created = try container.decode(Date.self, forKey: .created)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(created, forKey: .created)
    }
}

class TPGPTMessage: IMessage, Codable, Identifiable {
    @Published var text: String
    var textPublisher: Published<String>.Publisher { $text }
    
    var id: String
    var model: String
    var object: String
    var created: Date
    var choice: TPGPTMessageDetails?
    var isUser: Bool {
        return false
    }
    
    enum CodingKeys: CodingKey {
        case id
        case model
        case object
        case created
        case choices
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.model = try container.decode(String.self, forKey: .model)
        self.object = try container.decode(String.self, forKey: .object)
        self.created = try container.decode(Date.self, forKey: .created)
        
        let choices = try container.decode([TPGPTMessageDetails].self, forKey: .choices)
        choice = choices.first
        text = choice?.text ?? ""
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.model, forKey: .model)
        try container.encode(self.object, forKey: .object)
        try container.encode(self.created, forKey: .created)
        try container.encode([self.choice], forKey: .choices)
    }
    
    func updateNewText(newText: String) {
        var newText = newText
        newText.trimFirstNewLines()
        choice?.updateNewText(newText: newText)
        text = newText
//        print("[NEW TEXT]: ", newText)
    }
}

struct TPGPTMessageDetails: Codable {
    private(set) var text: String
    
    var finishReason: String?
    var index: Int
    
    enum CodingKeys: String, CodingKey {
        case finishReason = "finish_reason"
        case index
        case text
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        finishReason = try container.decode(String?.self, forKey: .finishReason)
        index = try container.decode(Int.self, forKey: .index)
        text = try container.decode(String.self, forKey: .text)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(finishReason, forKey: .finishReason)
        try container.encode(index, forKey: .index)
        try container.encode(text, forKey: .text)
    }
    
    fileprivate mutating func updateNewText(newText: String) {
        self.text = newText
    }
}

struct TPMessage: Identifiable, Hashable {
    let id: String = UUID().uuidString
    var data: IMessage
    var dataId: String {
        return data.id
    }
    
    static func == (lhs: TPMessage, rhs: TPMessage) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
