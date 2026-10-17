//
//  ZineRepository.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import Foundation
import UIKit

/// Zine storage used by the view models.
@MainActor
protocol ZineRepository: AnyObject {
    /// Every stored zine, unsorted.
    func fetchSummaries() throws -> [ZineSummary]

    /// Creates and stores an empty zine.
    ///
    /// - Parameter title: The initial title.
    /// - Returns: The new zine's summary.
    @discardableResult
    func createZine(title: String) throws -> ZineSummary

    /// Changes the title of a stored zine.
    func rename(_ id: UUID, to title: String) throws

    /// Copies a zine, including drawings and assets.
    ///
    /// - Returns: The summary of the copy.
    @discardableResult
    func duplicate(_ id: UUID) throws -> ZineSummary

    /// Permanently deletes a zine.
    func delete(_ id: UUID) throws

    /// Loads a zine for reading or editing.
    func openDocument(_ id: UUID) throws -> ZineDocument

    /// Saved cover image.
    func coverImage(for id: UUID) -> UIImage?
}

/// Errors raised by a ``ZineRepository``.
enum ZineRepositoryError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: return "A revista não foi encontrada."
        }
    }
}

// MARK: - File system implementation

/// Stores one ``ZinePackage`` per zine in `Documents/Zines`.
@MainActor
final class FileZineRepository: ZineRepository {
    /// Folder that holds every `.zine` package.
    let rootURL: URL

    /// - Parameter rootURL: Storage folder for previews and tests.
    ///   Defaults to `Documents/Zines`.
    init(rootURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.rootURL = rootURL ?? documents.appendingPathComponent("Zines", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
    }

    // MARK: ZineRepository

    func fetchSummaries() throws -> [ZineSummary] {
        let urls = try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
        return urls
            .filter { $0.pathExtension == "zine" }
            .compactMap { url in
                let package = ZinePackage(url: url)
                guard let zine = try? package.readManifest() else { return nil }
                return summary(of: zine, in: package)
            }
    }

    func createZine(title: String) throws -> ZineSummary {
        let zine = Zine.blank(title: title)
        let package = self.package(for: zine.id)
        try package.writeManifest(zine)
        return summary(of: zine, in: package)
    }

    func rename(_ id: UUID, to title: String) throws {
        let package = try existingPackage(for: id)
        var zine = try package.readManifest()
        zine.title = title
        zine.modifiedAt = Date()
        try package.writeManifest(zine)
    }

    func duplicate(_ id: UUID) throws -> ZineSummary {
        let source = try existingPackage(for: id)
        var zine = try source.readManifest()
        zine.id = UUID()
        zine.title += " (cópia)"
        zine.createdAt = Date()
        zine.modifiedAt = Date()

        let destination = package(for: zine.id)
        try FileManager.default.copyItem(at: source.url, to: destination.url)
        try destination.writeManifest(zine)
        return summary(of: zine, in: destination)
    }

    func delete(_ id: UUID) throws {
        try FileManager.default.removeItem(at: existingPackage(for: id).url)
    }

    func openDocument(_ id: UUID) throws -> ZineDocument {
        try ZineDocument(package: existingPackage(for: id))
    }

    func coverImage(for id: UUID) -> UIImage? {
        UIImage(contentsOfFile: package(for: id).thumbnailURL.path)
    }

    // MARK: Helpers

    private func package(for id: UUID) -> ZinePackage {
        ZinePackage(url: rootURL.appendingPathComponent("\(id.uuidString).zine", isDirectory: true))
    }

    private func existingPackage(for id: UUID) throws -> ZinePackage {
        let package = self.package(for: id)
        guard FileManager.default.fileExists(atPath: package.manifestURL.path) else {
            throw ZineRepositoryError.notFound
        }
        return package
    }

    private func summary(of zine: Zine, in package: ZinePackage) -> ZineSummary {
        ZineSummary(id: zine.id,
                    title: zine.title,
                    createdAt: zine.createdAt,
                    modifiedAt: zine.modifiedAt,
                    hasCoverArt: coverHasArt(zine, in: package))
    }

    /// `true` when the cover has an image, a paper color or a drawing.
    private func coverHasArt(_ zine: Zine, in package: ZinePackage) -> Bool {
        guard let cover = zine.pages.first else { return false }
        if cover.paperColor != .paper { return true }
        return cover.layers.contains { layer in
            switch layer.content {
            case .image, .text:
                return true
            case .drawing:
                // An empty PKDrawing file is a few dozen bytes.
                return package.drawingFileSize(for: layer.id) > 400
            }
        }
    }
}
