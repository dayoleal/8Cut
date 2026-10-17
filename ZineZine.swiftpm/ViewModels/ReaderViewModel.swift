//
//  ReaderViewModel.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import UIKit
import Observation

/// Navigation requested by the reader (implemented by ``AppViewModel``).
@MainActor
protocol ReaderRouting: AnyObject {
    func closeReader(saving document: ZineDocument)
    func showEditor(for document: ZineDocument)
    func duplicate(_ document: ZineDocument)
    func delete(_ document: ZineDocument)
}

/// State and actions of the reading mode, including the spread logic used by
/// ``BookSpreadView``.
///
/// Spreads of an 8-page zine:
/// ```
/// 0: [ —          | cover ]   closed, showing the cover
/// 1: [ page 1     | page 2 ]
/// 2: [ page 3     | page 4 ]
/// 3: [ page 5     | page 6 ]
/// 4: [ back cover | —      ]  closed, showing the back
/// ```
@MainActor
@Observable
final class ReaderViewModel {
    /// The zine being read.
    let document: ZineDocument

    /// Current spread.
    var spread = 0
    var isRenaming = false
    var draftTitle = ""
    var isConfirmingDeletion = false
    var shareItems: ShareItems?

    @ObservationIgnored weak var router: ReaderRouting?

    init(document: ZineDocument, router: ReaderRouting? = nil) {
        self.document = document
        self.router = router
    }

    // MARK: Derived state

    var title: String { document.zine.title }
    var deletionTitle: String { "Apagar \"\(title)\"?" }
    var pageCount: Int { document.pages.count }

    /// Number shown in the page counter: the right-hand page, or the back cover.
    var currentPageNumber: Int { min(spread * 2 + 1, pageCount) }

    /// Page artwork for the book view.
    func pageImage(at index: Int) -> UIImage? {
        // Reading the revision registers observation, so the book recomposes on change.
        _ = document.contentRevision
        return document.readerImage(for: index)
    }

    // MARK: Spreads

    /// Number of spreads (5 for 8 pages).
    var spreadCount: Int { pageCount / 2 + 1 }
    var lastSpread: Int { spreadCount - 1 }

    /// Page on the left of a spread, or `nil` when the zine is closed on that side.
    func leftPageIndex(ofSpread spread: Int) -> Int? {
        let index = spread * 2 - 1
        return (0..<pageCount).contains(index) ? index : nil
    }

    /// Page on the right of a spread, or `nil` when the zine is closed on that side.
    func rightPageIndex(ofSpread spread: Int) -> Int? {
        let index = spread * 2
        return (0..<pageCount).contains(index) ? index : nil
    }

    /// How many pages are stacked under a left page (drawn at most 3).
    func pagesBelow(leftPage index: Int) -> Int { min(index, 3) }

    /// How many pages are stacked under a right page (drawn at most 3).
    func pagesBelow(rightPage index: Int) -> Int { min(pageCount - 1 - index, 3) }

    /// Horizontal offset of the book, as a fraction of a page width: a closed
    /// zine (cover or back cover) is centered on screen.
    func bookOffsetFactor(forSpread spread: Int) -> CGFloat {
        if spread <= 0 { return -0.5 }
        if spread >= lastSpread { return 0.5 }
        return 0
    }

    /// Limits a drag progress to the flips that are possible from the current spread.
    ///
    /// - Parameter rawProgress: Drag distance in page widths; positive flips forward.
    /// - Returns: The progress clamped to `-1...1`.
    func clampedFlipProgress(_ rawProgress: Double) -> Double {
        var progress = rawProgress
        if spread >= lastSpread { progress = min(progress, 0) }
        if spread <= 0 { progress = max(progress, 0) }
        return max(-1, min(1, progress))
    }

    /// Whether a released drag should complete the flip.
    ///
    /// - Parameters:
    ///   - progress: Progress when the finger lifted.
    ///   - predictedProgress: Progress predicted from the release velocity.
    func shouldCommitFlip(progress: Double, predictedProgress: Double) -> Bool {
        let sameDirection = predictedProgress.sign == progress.sign
        return abs(progress) > 0.5 || (sameDirection && abs(predictedProgress) > 0.8)
    }

    /// Whether there is a spread in that direction.
    func canFlip(forward: Bool) -> Bool {
        (0...lastSpread).contains(spread + (forward ? 1 : -1))
    }

    /// Moves to the next (`1`) or previous (`-1`) spread after the flip animation.
    func completeFlip(direction: Int) {
        let next = spread + direction
        guard (0...lastSpread).contains(next) else { return }
        spread = next
    }

    // MARK: Actions

    func close() { router?.closeReader(saving: document) }
    func edit() { router?.showEditor(for: document) }
    func duplicate() { router?.duplicate(document) }

    func beginRename() {
        draftTitle = title
        isRenaming = true
    }

    func commitRename() {
        document.rename(to: draftTitle)
        document.saveNow()
    }

    func requestDeletion() { isConfirmingDeletion = true }
    func confirmDeletion() { router?.delete(document) }

    func share() {
        document.saveNow()
        shareItems = ShareItems(images: document.shareImages())
    }
}
