//
//  Created by Alex.M on 20.06.2022.
//

import Foundation
import Combine
import ExyteMediaPicker
import SwiftUI

@MainActor
final class InputViewModel: ObservableObject {

    @Published var text = ""
    @Published var attachments = InputViewAttachments()
    @Published var state: InputViewState = .empty

    @Published var showPicker = false
    @Published var showDocumentPicker = false
    @Published var showLocationPicker = false

    @Published var mediaPickerMode = MediaPickerMode.photos

    @Published var showActivityIndicator = false

    var didSendMessage: ((DraftMessage) -> Void)?

    private var saveEditingClosure: ((String) -> Void)?

    private var subscriptions = Set<AnyCancellable>()

    func onStart() {
        subscribeValidation()
    }

    func onStop() {
        subscriptions.removeAll()
    }

    func reset() {
        text = ""
        attachments = InputViewAttachments()
        state = .empty
        showPicker = false
        showDocumentPicker = false
        showLocationPicker = false
        saveEditingClosure = nil
        subscribeValidation()
    }

    func send() {
        sendMessage()
    }

    func edit(_ closure: @escaping (String) -> Void) {
        saveEditingClosure = closure
        state = .editing
    }

    func inputViewAction() -> (InputViewAction) -> Void {
        { [weak self] in
            self?.inputViewActionInternal($0)
        }
    }

    private func inputViewActionInternal(_ action: InputViewAction) {
        switch action {
        case .photo:
            mediaPickerMode = .photos
            showPicker = true
        case .add:
            mediaPickerMode = .camera
        case .camera:
            mediaPickerMode = .camera
            showPicker = true
        case .document:
            showDocumentPicker = true
        case .location:
            showLocationPicker = true
        case .send:
            send()
        case .saveEdit:
            saveEditingClosure?(text)
            reset()
        case .cancelEdit:
            reset()
        }
    }
}

private extension InputViewModel {

    func validateDraft() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard state != .editing else { return } // special case
            let hasAttachments = !self.attachments.medias.isEmpty || !self.attachments.documents.isEmpty || self.attachments.staticLocation != nil || self.attachments.liveLocation != nil
            if !self.text.isEmpty || hasAttachments {
                self.state = .hasTextOrMedia
            } else if self.text.isEmpty, !hasAttachments {
                self.state = .empty
            }
        }
    }

    func subscribeValidation() {
        $attachments.sink { [weak self] _ in
            self?.validateDraft()
        }
        .store(in: &subscriptions)

        $text.sink { [weak self] _ in
            self?.validateDraft()
        }
        .store(in: &subscriptions)
    }
}

private extension InputViewModel {

    func sendMessage() {
        showActivityIndicator = true
        // live location shares need a stable id upfront so subsequent location updates can find this message again
        let messageId = (attachments.liveLocation != nil) ? UUID().uuidString : nil
        let draft = DraftMessage(
            id: messageId,
            text: text,
            medias: attachments.medias,
            documents: attachments.documents,
            staticLocation: attachments.staticLocation,
            liveLocation: attachments.liveLocation,
            replyMessage: attachments.replyMessage,
            createdAt: Date()
        )
        didSendMessage?(draft)
        showActivityIndicator = false
        reset()
    }
}
