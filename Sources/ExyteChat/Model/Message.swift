//
//  Message.swift
//  Chat
//
//  Created by Alisa Mylnikova on 20.04.2022.
//

import SwiftUI

public struct Message: Identifiable, Sendable {

    public enum Status: Equatable, Hashable, Sendable {
        case sending
        case sent
        case delivered
        case read
        case error(DraftMessage)

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .sending:
                return hasher.combine("sending")
            case .sent:
                return hasher.combine("sent")
            case .delivered:
                return hasher.combine("delivered")
            case .read:
                return hasher.combine("read")
            case .error:
                return hasher.combine("error")
            }
        }

        public static func == (lhs: Message.Status, rhs: Message.Status) -> Bool {
            switch (lhs, rhs) {
            case (.sending, .sending):
                return true
            case (.sent, .sent):
                return true
            case (.delivered, .delivered):
                return true
            case (.read, .read):
                return true
            case ( .error(_), .error(_)):
                return true
            default:
                return false
            }
        }
    }

    public var id: String
    public var user: User
    public var status: Status?
    public var createdAt: Date

    public var attributedText: AttributedString
    public var reactions: [Reaction]
    public var replyMessage: ReplyMessage?
    public var customData: [String: any Sendable]

    public var triggerRedraw: UUID?

    public var hasText: Bool {
        !attributedText.characters.isEmpty
    }

    public var text: String {
        String(attributedText.characters)
    }

    public init(
        id: String,
        user: User,
        status: Status? = nil,
        createdAt: Date = Date(),
        text: String = "",
        reactions: [Reaction] = [],
        replyMessage: ReplyMessage? = nil,
        customData: [String: any Sendable] = [:]
    ) {
        self.id = id
        self.user = user
        self.status = status
        self.createdAt = createdAt
        self.attributedText = text.applyDefaultAttributes()
        self.reactions = reactions
        self.replyMessage = replyMessage
        self.customData = customData
    }

    public init(
        id: String,
        user: User,
        status: Status? = nil,
        createdAt: Date = Date(),
        attributedText: AttributedString,
        reactions: [Reaction] = [],
        replyMessage: ReplyMessage? = nil,
        customData: [String: any Sendable] = [:]
    ) {
        self.id = id
        self.user = user
        self.status = status
        self.createdAt = createdAt
        self.attributedText = attributedText
        self.reactions = reactions
        self.replyMessage = replyMessage
        self.customData = customData
    }

    public static func makeMessage(
        id: String,
        user: User,
        status: Status? = nil,
        draft: DraftMessage
    ) async -> Message {
        return Message(
            id: id,
            user: user,
            status: status,
            createdAt: draft.createdAt,
            text: draft.text,
            replyMessage: draft.replyMessage
        )
    }
}

extension Message {
    var formattedDate: String {
        DateFormatter.timeFormatter.string(from: createdAt)
    }
}

extension Message: Equatable {
    public static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id &&
        lhs.user == rhs.user &&
        lhs.status == rhs.status &&
        lhs.createdAt == rhs.createdAt &&
        lhs.attributedText == rhs.attributedText &&
        lhs.reactions == rhs.reactions &&
        lhs.replyMessage == rhs.replyMessage &&
        lhs.triggerRedraw == rhs.triggerRedraw
    }
}

public struct Recording: Codable, Hashable, Sendable {
    public var duration: Double
    public var waveformSamples: [CGFloat]
    public var url: URL?

    public init(duration: Double = 0.0, waveformSamples: [CGFloat] = [], url: URL? = nil) {
        self.duration = duration
        self.waveformSamples = waveformSamples
        self.url = url
    }
}

public struct ReplyMessage: Codable, Identifiable, Hashable, Sendable {
    public static func == (lhs: ReplyMessage, rhs: ReplyMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.user == rhs.user &&
        lhs.createdAt == rhs.createdAt &&
        lhs.attributedText == rhs.attributedText
    }

    public var id: String
    public var user: User
    public var createdAt: Date

    public var attributedText: AttributedString

    public var text: String {
        String(attributedText.characters)
    }

    public init(
        id: String,
        user: User,
        createdAt: Date,
        text: String = ""
    ) {
        self.id = id
        self.user = user
        self.createdAt = createdAt
        self.attributedText = text.applyDefaultAttributes()
    }

    public init(
        id: String,
        user: User,
        createdAt: Date,
        attributedText: AttributedString
    ) {
        self.id = id
        self.user = user
        self.createdAt = createdAt
        self.attributedText = attributedText
    }

    func toMessage() -> Message {
        Message(id: id, user: user, createdAt: createdAt, attributedText: attributedText)
    }
}

public extension Message {
    func toReplyMessage() -> ReplyMessage {
        ReplyMessage(id: id, user: user, createdAt: createdAt, attributedText: attributedText)
    }
}
