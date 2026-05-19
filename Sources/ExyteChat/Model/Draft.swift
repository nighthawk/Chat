//
//  Created by Alex.M on 17.06.2022.
//

import Foundation

public struct DraftMessage: Sendable {
    public var id: String?
    public let text: String
    public let replyMessage: ReplyMessage?
    public let createdAt: Date
    
    public init(id: String? = nil,
                text: String,
                replyMessage: ReplyMessage?,
                createdAt: Date) {
        self.id = id
        self.text = text
        self.replyMessage = replyMessage
        self.createdAt = createdAt
    }
}

