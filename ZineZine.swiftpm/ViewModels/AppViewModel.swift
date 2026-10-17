//
//  AppViewModel.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import Foundation
import Observation

/// Root view model: owns navigation and creates the screen view models.
///
/// Screens never navigate by themselves; their view models call the routing
/// protocols implemented here (``GalleryRouting``, ``ReaderRouting`` and
/// ``EditorRouting``). The ``ZineRepository`` is injected once and shared.
@MainActor
@Observable
final class AppViewModel {
    /// The screen currently shown.
    enum Screen {
        case gallery
        case reader(ReaderViewModel)
        case editor(EditorViewModel)

        /// Stable identifier used to animate screen changes.
        var id: String {
            switch self {
            case .gallery: return "gallery"
            // ObjectIdentifier is not actor-isolated, unlike the view model's properties.
            case .reader(let viewModel): return "reader-\(ObjectIdentifier(viewModel).hashValue)"
            case .editor(let viewModel): return "editor-\(ObjectIdentifier(viewModel).hashValue)"
            }
        }
    }

    private(set) var screen: Screen = .gallery
    /// Kept alive between visits to preserve sort and search.
    let galleryViewModel: GalleryViewModel

    private let repository: ZineRepository

    /// - Parameter repository: Storage shared by every screen.
    init(repository: ZineRepository) {
        self.repository = repository
        self.galleryViewModel = GalleryViewModel(repository: repository)
        galleryViewModel.router = self
    }

    private func showGallery() {
        galleryViewModel.reload()
        screen = .gallery
    }
}

// MARK: - GalleryRouting

extension AppViewModel: GalleryRouting {
    func showReader(for document: ZineDocument) {
        screen = .reader(ReaderViewModel(document: document, router: self))
    }

    func showEditor(for document: ZineDocument) {
        screen = .editor(EditorViewModel(document: document, router: self))
    }
}

// MARK: - ReaderRouting

extension AppViewModel: ReaderRouting {
    func closeReader(saving document: ZineDocument) {
        document.saveNow()
        showGallery()
    }

    func duplicate(_ document: ZineDocument) {
        document.saveNow()
        _ = try? repository.duplicate(document.zine.id)
        showGallery()
    }

    func delete(_ document: ZineDocument) {
        try? repository.delete(document.zine.id)
        showGallery()
    }
}

// MARK: - EditorRouting

extension AppViewModel: EditorRouting {
    func closeEditor(saving document: ZineDocument) {
        document.saveNow()
        showGallery()
    }
}
