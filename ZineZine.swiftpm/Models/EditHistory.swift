//
//  EditHistory.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import Foundation
import Observation

/// The single undo/redo stack of an open document (Command pattern).
///
/// PencilKit ships its own undo, but it lives in the canvas' `UndoManager` and is
/// lost when the canvas switches page or layer. Every edit is therefore recorded
/// here as an ``Entry`` that knows how to undo and redo itself and remembers the
/// page it happened on, so the editor can navigate back to it.
@MainActor
@Observable
final class EditHistory {
    /// A reversible edit.
    struct Entry {
        /// Short description, e.g. "Traço".
        let name: String
        /// Page affected by the edit, if any.
        let pageIndex: Int?
        let undo: @MainActor () -> Void
        let redo: @MainActor () -> Void
    }

    private var undoStack: [Entry] = []
    private var redoStack: [Entry] = []

    /// Maximum number of undo steps kept in memory.
    @ObservationIgnored var limit = 200

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Recording

    /// Records an edit that has already been applied. Clears the redo stack.
    ///
    /// - Parameters:
    ///   - name: Short description of the edit.
    ///   - pageIndex: Page affected by the edit.
    ///   - undo: Restores the state before the edit.
    ///   - redo: Re-applies the edit.
    func record(_ name: String,
                pageIndex: Int?,
                undo: @escaping @MainActor () -> Void,
                redo: @escaping @MainActor () -> Void) {
        undoStack.append(Entry(name: name, pageIndex: pageIndex, undo: undo, redo: redo))
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
        redoStack.removeAll()
    }

    // MARK: - Undo & redo

    /// Undoes the latest edit.
    ///
    /// - Returns: The page affected by the edit, or `nil` if nothing was undone.
    @discardableResult
    func undo() -> Int? {
        guard let entry = undoStack.popLast() else { return nil }
        entry.undo()
        redoStack.append(entry)
        return entry.pageIndex
    }

    /// Redoes the latest undone edit.
    ///
    /// - Returns: The page affected by the edit, or `nil` if nothing was redone.
    @discardableResult
    func redo() -> Int? {
        guard let entry = redoStack.popLast() else { return nil }
        entry.redo()
        undoStack.append(entry)
        return entry.pageIndex
    }

    /// Discards the whole history.
    func removeAll() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
