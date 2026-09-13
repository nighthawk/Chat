//
//  Media.swift
//  Chat
//
//  A photo or video the user picked with the system photo picker.
//
//  This is the fork's stand-in for ExyteMediaPicker's `Media`: it keeps the same
//  accessors so draft handling code reads unchanged, but is backed directly by
//  PhotosUI.
//

import Foundation
import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers
import AVFoundation
import UIKit

public enum MediaType: String, Codable, Sendable {
    case image
    case video
}

public struct Media: Identifiable, Equatable, Sendable {

    public let id: String
    public let type: MediaType

    private let loader: MediaLoader

    init(item: PhotosPickerItem) {
        self.id = UUID().uuidString
        self.type = Media.resolveType(for: item)
        self.loader = MediaLoader(item: item)
    }

    public var duration: CGFloat? {
        get async {
            guard type == .video, let url = await getURL() else { return nil }
            let asset = AVURLAsset(url: url)
            guard let duration = try? await asset.load(.duration) else { return nil }
            return CGFloat(CMTimeGetSeconds(duration))
        }
    }

    public func getURL() async -> URL? {
        await loader.url()
    }

    /// The system picker exposes no separate thumbnail asset, so this is the full item.
    public func getThumbnailURL() async -> URL? {
        await getURL()
    }

    public func getData() async throws -> Data? {
        guard let url = await getURL() else { return nil }
        return try Data(contentsOf: url)
    }

    public func getThumbnailData() async -> Data? {
        guard let url = await getURL() else { return nil }
        guard type == .video else {
            return try? Data(contentsOf: url)
        }
        return await Media.videoThumbnailData(url: url)
    }

    public static func == (lhs: Media, rhs: Media) -> Bool {
        lhs.id == rhs.id
    }

    private static func resolveType(for item: PhotosPickerItem) -> MediaType {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            return .video
        }
        return .image
    }

    private static func videoThumbnailData(url: URL) async -> Data? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        guard let cgImage = try? await generator.image(at: .zero).image else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8)
    }
}

/// Copies the file backing a `PhotosPickerItem` to a temporary URL, once, so it can be
/// read more than once — the photo library's own URLs are only valid transiently.
private actor MediaLoader {

    private let item: PhotosPickerItem
    private var cachedURL: URL?

    init(item: PhotosPickerItem) {
        self.item = item
    }

    func url() async -> URL? {
        if let cachedURL { return cachedURL }
        guard let file = try? await item.loadTransferable(type: TransferFile.self) else { return nil }
        cachedURL = file.url
        return file.url
    }
}

private struct TransferFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .item) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            let copy = URL.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}
