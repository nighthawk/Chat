//
//  SystemPhotoPicker.swift
//  Chat
//
//  Presents PhotosUI's system photo picker and feeds its results into the
//  draft attachment pipeline as `Media`.
//

import SwiftUI
import PhotosUI

struct SystemPhotoPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    var selectionParameters: MediaPickerSelectionParameters
    var onSelect: ([Media]) -> Void

    @State private var selection: [PhotosPickerItem] = []

    private var matchingFilter: PHPickerFilter {
        switch selectionParameters.mediaType {
        case .photo: return .images
        case .video: return .videos
        case .photoAndVideo: return .any(of: [.images, .videos])
        }
    }

    private var selectionBehavior: PhotosPickerSelectionBehavior {
        switch selectionParameters.selectionStyle {
        case .checkmark: return .default
        case .count: return .ordered
        }
    }

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: $isPresented,
                selection: $selection,
                maxSelectionCount: selectionParameters.selectionLimit,
                selectionBehavior: selectionBehavior,
                matching: matchingFilter
            )
            .onChange(of: selection) { _, newValue in
                guard !newValue.isEmpty else { return }
                let medias = newValue.map { Media(item: $0) }
                selection = []
                onSelect(medias)
            }
    }
}

extension View {
    func systemPhotoPicker(
        isPresented: Binding<Bool>,
        selectionParameters: MediaPickerSelectionParameters,
        onSelect: @escaping ([Media]) -> Void
    ) -> some View {
        modifier(SystemPhotoPickerModifier(isPresented: isPresented, selectionParameters: selectionParameters, onSelect: onSelect))
    }
}
