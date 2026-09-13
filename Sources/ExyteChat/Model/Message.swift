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
        case readBy([String]) // user ids
        case error(DraftMessage)

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .sending:
                return hasher.combine("sending")
            case .sent:
                return hasher.combine("sent")
            case .delivered:
                return hasher.combine("delivered")
            case .readBy:
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
            case (.readBy(let r1), .readBy(let r2)):
                return r1 == r2
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
    public var attachments: [Attachment]
    public var reactions: [Reaction]
    public var staticLocation: StaticLocation?
    public var liveLocation: LiveLocation?
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
        attachments: [Attachment] = [],
        staticLocation: StaticLocation? = nil,
        liveLocation: LiveLocation? = nil,
        reactions: [Reaction] = [],
        replyMessage: ReplyMessage? = nil,
        customData: [String: any Sendable] = [:]
    ) {
        self.id = id
        self.user = user
        self.status = status
        self.createdAt = createdAt
        self.attributedText = text.applyDefaultAttributes()
        self.attachments = attachments
        self.staticLocation = staticLocation
        self.liveLocation = liveLocation
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
        attachments: [Attachment] = [],
        staticLocation: StaticLocation? = nil,
        liveLocation: LiveLocation? = nil,
        reactions: [Reaction] = [],
        replyMessage: ReplyMessage? = nil,
        customData: [String: any Sendable] = [:]
    ) {
        self.id = id
        self.user = user
        self.status = status
        self.createdAt = createdAt
        self.attributedText = attributedText
        self.attachments = attachments
        self.staticLocation = staticLocation
        self.liveLocation = liveLocation
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
        let attachments = await draft.medias.asyncCompactMap { media -> Attachment? in
            guard let thumbnailURL = await media.getThumbnailURL() else {
                return nil
            }

            switch media.type {
            case .image:
                return Attachment(id: UUID().uuidString, url: thumbnailURL, type: .image)
            case .video:
                guard let fullURL = await media.getURL() else {
                    return nil
                }
                return Attachment(id: UUID().uuidString, thumbnail: thumbnailURL, full: fullURL, type: .video)
            }
        }

        let documentAttachments = draft.documents.map { document in
            Attachment(id: document.id, url: document.url, type: .document, fileName: document.fileName, fileSize: document.fileSize)
        }

        return Message(
            id: id,
            user: user,
            status: status,
            createdAt: draft.createdAt,
            text: draft.text,
            attachments: attachments + documentAttachments,
            staticLocation: draft.staticLocation,
            liveLocation: draft.liveLocation,
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
        lhs.staticLocation == rhs.staticLocation &&
        lhs.liveLocation == rhs.liveLocation &&
        lhs.attachments == rhs.attachments &&
        lhs.reactions == rhs.reactions &&
        lhs.replyMessage == rhs.replyMessage &&
        lhs.triggerRedraw == rhs.triggerRedraw
    }
}

public struct ReplyMessage: Codable, Identifiable, Hashable, Sendable {
    public static func == (lhs: ReplyMessage, rhs: ReplyMessage) -> Bool {
        lhs.id == rhs.id &&
        lhs.user == rhs.user &&
        lhs.createdAt == rhs.createdAt &&
        lhs.attributedText == rhs.attributedText &&
        lhs.attachments == rhs.attachments
    }

    public var id: String
    public var user: User
    public var createdAt: Date

    public var attributedText: AttributedString
    public var attachments: [Attachment]

    public var text: String {
        String(attributedText.characters)
    }

    public init(
        id: String,
        user: User,
        createdAt: Date,
        text: String = "",
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.user = user
        self.createdAt = createdAt
        self.attributedText = text.applyDefaultAttributes()
        self.attachments = attachments
    }

    public init(
        id: String,
        user: User,
        createdAt: Date,
        attributedText: AttributedString,
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.user = user
        self.createdAt = createdAt
        self.attributedText = attributedText
        self.attachments = attachments
    }

    func toMessage() -> Message {
        Message(id: id, user: user, createdAt: createdAt, attributedText: attributedText, attachments: attachments)
    }
}

public extension Message {
    func toReplyMessage() -> ReplyMessage {
        ReplyMessage(id: id, user: user, createdAt: createdAt, attributedText: attributedText, attachments: attachments)
    }
}
