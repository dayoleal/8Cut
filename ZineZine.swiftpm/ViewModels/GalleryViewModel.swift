//
//  GalleryViewModel.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import Foundation
import UIKit
import Observation

/// Navigation requested by the gallery (implemented by ``AppViewModel``).
@MainActor
protocol GalleryRouting: AnyObject {
    /// Shows a zine in the reader.
    func showReader(for document: ZineDocument)
    /// Shows a zine in the editor.
    func showEditor(for document: ZineDocument)
}

/// State and actions of the "Suas Revistas" screen.
///
/// Fetches zines from the ``ZineRepository``, filters and sorts them, loads the
/// covers and drives every alert of the screen. ``GalleryView`` only renders.
@MainActor
@Observable
final class GalleryViewModel {
    // MARK: State

    private(set) var summaries: [ZineSummary] = []
    var sortOrder: ZineSortOrder = .modified
    var isSearching = false
    var query = ""

    /// Zine being renamed (drives the rename alert).
    var renamingItem: ZineSummary?
    var draftTitle = ""
    /// Zine waiting for delete confirmation.
    var pendingDeletion: ZineSummary?
    /// Message for the error alert.
    var errorMessage: String?

    // MARK: Dependencies

    private let repository: ZineRepository
    @ObservationIgnored weak var router: GalleryRouting?
    /// Covers already read from disk, keyed by zine and invalidated by `modifiedAt`.
    @ObservationIgnored private var coverCache: [UUID: (modifiedAt: Date, image: UIImage?)] = [:]

    /// - Parameters:
    ///   - repository: Where zines are stored.
    ///   - router: Navigation handler, usually the app coordinator.
    init(repository: ZineRepository, router: GalleryRouting? = nil) {
        self.repository = repository
        self.router = router
        reload()
    }

    // MARK: Derived state

    /// Summaries filtered by ``query`` and sorted by ``sortOrder``.
    var visibleItems: [ZineSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.isEmpty
            ? summaries
            : summaries.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
        return sortOrder.sorted(filtered)
    }

    /// The "+" card is hidden while searching.
    var showsNewZineCard: Bool { query.isEmpty }

    /// Saved cover of a zine, read once per modification.
    func coverImage(for item: ZineSummary) -> UIImage? {
        if let cached = coverCache[item.id], cached.modifiedAt == item.modifiedAt {
            return cached.image
        }
        let image = repository.coverImage(for: item.id)
        coverCache[item.id] = (item.modifiedAt, image)
        return image
    }

    // MARK: Alert state

    /// Drives the rename alert.
    var isRenaming: Bool {
        get { renamingItem != nil }
        set { if !newValue { renamingItem = nil } }
    }

    /// Drives the delete confirmation.
    var isConfirmingDeletion: Bool {
        get { pendingDeletion != nil }
        set { if !newValue { pendingDeletion = nil } }
    }

    /// Drives the error alert.
    var isShowingError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    /// Title of the delete confirmation.
    var deletionTitle: String {
        "Apagar \"\(pendingDeletion?.title ?? "")\"?"
    }

    // MARK: Actions

    /// Re-reads the stored zines.
    func reload() {
        do {
            summaries = try repository.fetchSummaries()
        } catch {
            errorMessage = "Não foi possível carregar suas revistas: \(error.localizedDescription)"
        }
    }

    func toggleSearch() {
        isSearching.toggle()
        if !isSearching { query = "" }
    }

    /// Creates an empty zine and opens it in the editor.
    func createZine() {
        do {
            let summary = try repository.createZine(title: nextUntitledName())
            reload()
            open(summary, inEditor: true)
        } catch {
            errorMessage = "Não foi possível criar a revista: \(error.localizedDescription)"
        }
    }

    /// Opens a zine in the reader or directly in the editor.
    func open(_ item: ZineSummary, inEditor: Bool = false) {
        do {
            let document = try repository.openDocument(item.id)
            if inEditor {
                router?.showEditor(for: document)
            } else {
                router?.showReader(for: document)
            }
        } catch {
            errorMessage = "Não foi possível abrir \"\(item.title)\": \(error.localizedDescription)"
        }
    }

    func cancelRename() {
        renamingItem = nil
    }

    func beginRename(_ item: ZineSummary) {
        draftTitle = item.title
        renamingItem = item
    }

    func commitRename() {
        defer { renamingItem = nil }
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let item = renamingItem, !title.isEmpty else { return }
        perform { try repository.rename(item.id, to: title) }
    }

    func duplicate(_ item: ZineSummary) {
        perform { try repository.duplicate(item.id) }
    }

    func requestDeletion(_ item: ZineSummary) {
        pendingDeletion = item
    }

    func confirmDeletion() {
        defer { pendingDeletion = nil }
        guard let item = pendingDeletion else { return }
        perform { try repository.delete(item.id) }
    }

    // MARK: Helpers

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            errorMessage = error.localizedDescription
        }
        reload()
    }

    private func nextUntitledName() -> String {
        let base = "Zine sem título"
        let titles = Set(summaries.map(\.title))
        guard titles.contains(base) else { return base }
        var number = 2
        while titles.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }
}
