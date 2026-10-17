//
//  ZinePackage.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import Foundation

/// On-disk layout of a single zine.
struct ZinePackage: Sendable, Hashable {
    /// The package directory.
    let url: URL

    var manifestURL: URL { url.appendingPathComponent("manifest.json") }
    var thumbnailURL: URL { url.appendingPathComponent("thumbnail.jpg") }
    var drawingsURL: URL { url.appendingPathComponent("drawings", isDirectory: true) }
    var assetsURL: URL { url.appendingPathComponent("assets", isDirectory: true) }

    /// File holding the strokes of a drawing layer.
    func drawingURL(for layerID: UUID) -> URL {
        drawingsURL.appendingPathComponent("\(layerID.uuidString).drawing")
    }

    /// File holding an imported image.
    func assetURL(named name: String) -> URL {
        assetsURL.appendingPathComponent(name)
    }

    // MARK: - Reading

    /// Decodes `manifest.json`.
    func readManifest() throws -> Zine {
        let data = try Data(contentsOf: manifestURL)
        return try Self.makeDecoder().decode(Zine.self, from: data)
    }

    /// Raw strokes of a drawing layer, or `nil` if the layer was never saved.
    func readDrawingData(for layerID: UUID) -> Data? {
        try? Data(contentsOf: drawingURL(for: layerID))
    }

    /// Size in bytes of a drawing file (`0` if missing).
    func drawingFileSize(for layerID: UUID) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: drawingURL(for: layerID).path)
        return (attributes?[.size] as? NSNumber)?.intValue ?? 0
    }

    // MARK: - Writing

    /// Creates the package folders if needed.
    func createDirectories() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: drawingsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
    }

    func writeManifest(_ zine: Zine) throws {
        try createDirectories()
        let data = try Self.makeEncoder().encode(zine)
        try data.write(to: manifestURL, options: .atomic)
    }

    func writeDrawingData(_ data: Data, for layerID: UUID) throws {
        try data.write(to: drawingURL(for: layerID), options: .atomic)
    }

    func writeAsset(_ data: Data, named name: String) throws {
        try createDirectories()
        try data.write(to: assetURL(named: name), options: .atomic)
    }

    func writeThumbnail(_ data: Data) throws {
        try data.write(to: thumbnailURL, options: .atomic)
    }

    /// Deletes drawing files that no longer belong to any layer of the manifest.
    ///
    /// - Parameter layerIDs: The drawing layers that must be kept.
    func removeOrphanDrawings(keeping layerIDs: Set<UUID>) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: drawingsURL, includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "drawing" {
            let name = file.deletingPathExtension().lastPathComponent
            if let id = UUID(uuidString: name), !layerIDs.contains(id) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    // MARK: - Coding

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
