//
//  EditHistory.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import Foundation
import Observation

/// Undo/redo stack of an open document.
///
/// Used instead of the PencilKit `UndoManager`, which is reset when the canvas
/// changes page or layer. Each entry stores its page so the editor can show it.
@MainActor
@Observable
final class EditHistory {
    /// An undoable edit.
    struct Entry {
        /// Short description, e.g. "Traço".
        let name: String
        /// Page where the edit happened.
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

    /// Adds an edit that was already applied. Clears the redo stack.
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

    /// Clears both stacks.
    func removeAll() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
