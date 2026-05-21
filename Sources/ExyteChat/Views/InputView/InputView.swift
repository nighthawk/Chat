//
//  InputView.swift
//  Chat
//
//  Created by Alex.M on 25.05.2022.
//

import SwiftUI
import ExyteMediaPicker
import AnchoredPopup

public enum InputViewStyle: Sendable {
    case message
    case signature
}

public enum InputViewAction: Sendable {
    case photo
    case add
    case camera
    case send

    case location
    case document

    case saveEdit
    case cancelEdit
}

public enum InputViewState: Sendable {
    case empty
    case hasTextOrMedia

    case editing

    var canSend: Bool {
        switch self {
        case .hasTextOrMedia: return true
        default: return false
        }
    }
}

public enum AvailableInputType: Sendable {
    case text
    case media
    case document
    case location
}

public struct InputViewAttachments {
    var medias: [Media] = []
    var documents: [DocumentItem] = []
    var staticLocation: StaticLocation?
    var liveLocation: LiveLocation?
    var replyMessage: ReplyMessage?
}

struct InputView: View {
    
    @Environment(\.chatTheme) private var theme
    @Environment(\.mediaPickerTheme) private var pickerTheme
    @Environment(\.chatSize) private var chatSize

    @EnvironmentObject private var keyboardState: KeyboardState
    
    @ObservedObject var viewModel: InputViewModel
    var inputFieldId: UUID
    var style: InputViewStyle
    var availableInputs: [AvailableInputType]
    var photoPickerBackend: PhotoPickerBackend = .custom
    var localization: ChatLocalization

    private var onAction: (InputViewAction) -> Void {
        viewModel.inputViewAction()
    }
    
    private var state: InputViewState {
        viewModel.state
    }

    @State private var inputBarFrame: CGRect = .zero

    private let attachMenuLeftMargin: CGFloat = 14
    private let attachMenuGap: CGFloat = 16

    private struct AttachMenuItem {
        let icon: Image
        let title: String
        let action: InputViewAction
    }

    var body: some View {
        VStack {
            viewOnTop
                .padding(.top, 6)
                .transition(.move(edge: .bottom))

            HStack(alignment: .bottom, spacing: 10) {
                HStack(alignment: .bottom, spacing: 0) {
                    leftView
                    middleView
                    rightView
                }
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(style == .message ? theme.colors.inputBG : theme.colors.inputSignatureBG)
                }
                .frameGetter($inputBarFrame)

                rightOutsideButton
            }
            .padding(MessageView.horizontalScreenEdgePadding, 8)
        }
        .background(backgroundColor)
        .onDrag(towards: .bottom, ofAmount: 100...) {
            keyboardState.resignFirstResponder()
        }
    }
    
    @ViewBuilder
    var leftView: some View {
        switch style {
        case .message:
            leftButton
        case .signature:
            if viewModel.mediaPickerMode == .cameraSelection {
                addButton
            } else {
                Color.clear.frame(width: 12, height: 1)
            }
        }
    }

    @ViewBuilder
    var middleView: some View {
        Group {
            TextInputView(
                text: $viewModel.text,
                inputFieldId: inputFieldId,
                style: style,
                availableInputs: availableInputs,
                localization: localization
            )
        }
        .frame(minHeight: 48)
    }
    
    @ViewBuilder
    var rightView: some View {
        Group {
            switch state {
            case .hasTextOrMedia:
                if case .message = style, !viewModel.text.isEmpty {
                    clearTextButton
                }
            default:
                EmptyView()
            }
        }
        .frame(minHeight: 48)
    }
    
    @ViewBuilder
    var editingButtons: some View {
        HStack {
            Button {
                onAction(.cancelEdit)
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                    .padding(5)
                    .background(Circle().foregroundStyle(.red))
            }
            
            Button {
                onAction(.saveEdit)
            } label: {
                Image(systemName: "checkmark")
                    .foregroundStyle(.white)
                    .fontWeight(.bold)
                    .padding(5)
                    .background(Circle().foregroundStyle(.green))
            }
        }
    }
    
    @ViewBuilder
    var rightOutsideButton: some View {
        if state == .editing {
            editingButtons
                .frame(height: 48)
        } else {
            ZStack {
                sendButton
                    .disabled(!state.canSend)
            }
            .viewSize(48)
        }
    }

    @ViewBuilder
    var viewOnTop: some View {
        if style == .message, photoPickerBackend == .system, !viewModel.attachments.medias.isEmpty {
            mediaAttachmentsPreview
        }
        if style == .message, !viewModel.attachments.documents.isEmpty {
            documentAttachmentsPreview
        }
        if style == .message, let staticLocation = viewModel.attachments.staticLocation {
            staticLocationAttachmentPreview(staticLocation)
        }
        if style == .message, let liveLocation = viewModel.attachments.liveLocation {
            liveLocationAttachmentPreview(liveLocation)
        }
        if let message = viewModel.attachments.replyMessage {
            VStack(spacing: 8) {
                Rectangle()
                    .foregroundColor(theme.colors.messageFriendBG)
                    .frame(height: 2)
                
                HStack {
                    theme.images.reply.replyToMessage
                    Capsule()
                        .foregroundColor(theme.colors.messageMyBG)
                        .frame(width: 2)
                    VStack(alignment: .leading) {
                        Text(localization.replyToText + " " + message.user.name)
                            .font(.caption2)
                            .foregroundColor(theme.colors.mainCaptionText)
                        if !message.attributedText.characters.isEmpty {
                            Text(message.attributedText)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundColor(theme.colors.mainText)
                        }
                    }
                    .padding(.vertical, 2)
                    
                    Spacer()
                    
                    if let first = message.attachments.first {
                        AsyncImageView(attachment: first, size: CGSize(width: 30, height: 30))
                            .viewSize(30)
                            .cornerRadius(4)
                            .padding(.trailing, 16)
                    }
                    
                    theme.images.reply.cancelReply
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.attachments.replyMessage = nil
                            }
                        }
                }
                .padding(.horizontal, 26)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    var mediaAttachmentsPreview: some View {
        horizontalAttachmentsPreviewScroll {
            ForEach(viewModel.attachments.medias) { media in
                MediaAttachmentThumbnail(media: media) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.attachments.medias.removeAll { $0.id == media.id }
                    }
                }
            }
        }
    }

    var documentAttachmentsPreview: some View {
        horizontalAttachmentsPreviewScroll {
            ForEach(viewModel.attachments.documents) { document in
                DocumentAttachmentThumbnail(document: document) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.attachments.documents.removeAll { $0.id == document.id }
                    }
                }
            }
        }
    }

    private func horizontalAttachmentsPreviewScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                content()
            }
            .padding(.top, 8)
            .padding(.horizontal, 26)
        }
    }

    func staticLocationAttachmentPreview(_ staticLocation: StaticLocation) -> some View {
        HStack(spacing: 8) {
            theme.images.attachMenu.location
                .renderingMode(.template)
                .foregroundColor(theme.colors.mainText)

            Text(String(format: "%.4f, %.4f", staticLocation.latitude, staticLocation.longitude))
                .font(.caption)
                .foregroundColor(theme.colors.mainText)
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.attachments.staticLocation = nil
                }
            } label: {
                theme.images.mediaPicker.cross
                    .resizable()
                    .viewSize(10)
                    .padding(4)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
    }

    func liveLocationAttachmentPreview(_ liveLocation: LiveLocation) -> some View {
        HStack(spacing: 8) {
            theme.images.attachMenu.location
                .renderingMode(.template)
                .foregroundColor(theme.colors.mainTint)

            Text(localization.liveLocationText)
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.colors.mainTint)
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.attachments.liveLocation = nil
                }
            } label: {
                theme.images.mediaPicker.cross
                    .resizable()
                    .viewSize(10)
                    .padding(4)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
    }

    private var attachMenuItems: [AttachMenuItem] {
        var items: [AttachMenuItem] = []
        if isMediaAvailable() {
            items.append(AttachMenuItem(icon: theme.images.inputView.attach, title: localization.attachMediaText, action: .photo))
            if photoPickerBackend == .system {
                items.append(AttachMenuItem(icon: theme.images.inputView.attachCamera, title: localization.attachCameraText, action: .camera))
            }
        }
        if isDocumentAvailable() {
            items.append(AttachMenuItem(icon: theme.images.attachMenu.document, title: localization.attachDocumentText, action: .document))
        }
        if isLocationAvailable() {
            items.append(AttachMenuItem(icon: theme.images.attachMenu.location, title: localization.attachLocationText, action: .location))
        }
        return items
    }

    @ViewBuilder
    var leftButton: some View {
        let items = attachMenuItems

        if items.count > 1 {
            attachMenuButton(items: items)
        } else if let item = items.first, item.action == .photo {
            menuButton(action: .photo, image: theme.images.inputView.attach)
        } else if let item = items.first, item.action == .document {
            menuButton(action: .document, image: theme.images.attachMenu.document)
        } else if let item = items.first, item.action == .location {
            menuButton(action: .location, image: theme.images.attachMenu.location)
        }
    }

    private var attachMenuPopupId: String {
        "exyte-chat-attach-menu-\(inputFieldId)"
    }

    private func attachMenuContent(_ items: [AttachMenuItem]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                AttachMenuRow(icon: item.icon, title: item.title) {
                    onAction(item.action)
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.colors.inputBG)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
    }

    private func attachMenuButton(items: [AttachMenuItem]) -> some View {
        theme.images.inputView.attach
            .viewSize(24)
            .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 6))
            .useAsPopupAnchor(id: attachMenuPopupId) {
                attachMenuContent(items)
            } customize: {
                $0.position(.absolute(.bottomLeading, position: CGPoint(x: attachMenuLeftMargin, y: inputBarFrame.minY - attachMenuGap)))
                    .background(.none)
                    .closeOnTapOutside(true)
                    .animation(.default)
            }
    }

    func menuButton(action: InputViewAction, image: Image) -> some View {
        Button {
            onAction(action)
        } label: {
            image
                .resizable()
                .viewSize(24)
                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 6))
        }
    }

    var clearTextButton: some View {
        Button {
            viewModel.text = ""
        } label: {
            theme.images.inputView.clearText
                .resizable()
                .renderingMode(.template)
                .foregroundColor(theme.colors.mainText.opacity(0.6))
                .viewSize(18)
                .padding(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 12))
        }
    }

    var addButton: some View {
        Button {
            onAction(.add)
        } label: {
            theme.images.inputView.add
                .viewSize(24)
                .circleBackground(theme.colors.sendButtonBackground)
                .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 8))
        }
    }
    
    var sendButton: some View {
        Button {
            onAction(.send)
        } label: {
            theme.images.inputView.arrowSend
                .viewSize(48)
                .circleBackground(theme.colors.sendButtonBackground)
        }
    }
    
    
    var backgroundColor: Color {
        switch style {
        case .message:
            return theme.contentBG
        case .signature:
            return pickerTheme.main.pickerBackground
        }
    }

    private func isMediaAvailable() -> Bool {
        return availableInputs.contains(AvailableInputType.media)
    }

    private func isDocumentAvailable() -> Bool {
        return availableInputs.contains(AvailableInputType.document)
    }

    private func isLocationAvailable() -> Bool {
        return availableInputs.contains(AvailableInputType.location)
    }
}

private struct AttachMenuRow: View {
    @Environment(\.chatTheme) private var theme
    @Environment(\.anchoredPopupDismiss) private var dismissPopup

    let icon: Image
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
            dismissPopup?()
        } label: {
            HStack(spacing: 10) {
                icon
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .viewSize(20)
                    .foregroundColor(theme.colors.mainTint)
                Text(title)
                    .font(.callout)
                    .foregroundColor(theme.colors.mainText)
            }
            .padding(14, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RemovableAttachmentThumbnail<Content: View>: View {
    @Environment(\.chatTheme) var theme

    var onRemove: () -> Void
    @ViewBuilder var content: () -> Content

    private var thumbnailSize: CGFloat {
        UIScreen.main.bounds.width / 5
    }

    var body: some View {
        content()
            .viewSize(thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topTrailing) {
                Button(action: onRemove) {
                    theme.images.mediaPicker.cross
                        .resizable()
                        .viewSize(10)
                        .padding(4)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                        .foregroundColor(.white)
                }
                .offset(x: 6, y: -6)
            }
    }
}

private struct MediaAttachmentThumbnail: View {
    @Environment(\.chatTheme) private var theme
    @Environment(\.chatSize) private var chatSize

    var media: Media
    var onRemove: () -> Void

    @State private var thumbnail: UIImage?

    private var thumbnailSize: CGFloat {
        chatSize.width / 5
    }

    var body: some View {
        RemovableAttachmentThumbnail(onRemove: onRemove) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(theme.colors.messageFriendBG)
            }

            if media.type == .video {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
        }
        .task(id: media.id) {
            if let data = await media.getThumbnailData(), let image = UIImage(data: data) {
                thumbnail = image
            }
        }
    }
}

private struct DocumentAttachmentThumbnail: View {
    @Environment(\.chatTheme) var theme

    var document: DocumentItem
    var onRemove: () -> Void

    var body: some View {
        RemovableAttachmentThumbnail(onRemove: onRemove) {
            VStack(spacing: 4) {
                theme.images.message.attachedDocument
                    .resizable()
                    .scaledToFit()
                    .viewSize(28)

                Text(document.fileName)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(theme.colors.mainText)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colors.messageFriendBG)
        }
    }
}

@MainActor
func performBatchTableUpdates(_ tableView: UITableView, closure: ()->()) async {
    await withCheckedContinuation { continuation in
        tableView.performBatchUpdates {
            closure()
        } completion: { _ in
            continuation.resume()
        }
    }
}
