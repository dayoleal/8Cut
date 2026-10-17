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

/// View model of the reader. Spreads of an 8-page zine:
/// ```
/// 0: [            | cover ]
/// 1: [ page 1     | page 2 ]
/// 2: [ page 3     | page 4 ]
/// 3: [ page 5     | page 6 ]
/// 4: [ back cover |        ]
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
    /// Export screen, shown while set.
    var exportViewModel: ExportViewModel?

    @ObservationIgnored weak var router: ReaderRouting?

    init(document: ZineDocument, router: ReaderRouting? = nil) {
        self.document = document
        self.router = router
    }

    // MARK: Derived state

    var title: String { document.zine.title }
    var deletionTitle: String { "Apagar \"\(title)\"?" }
    var pageCount: Int { document.pages.count }

    /// Page number shown in the counter.
    var currentPageNumber: Int { min(spread * 2 + 1, pageCount) }

    /// Rendered page.
    func pageImage(at index: Int) -> UIImage? {
        // Read so the view updates when the content changes.
        _ = document.contentRevision
        return document.readerImage(for: index)
    }

    // MARK: Spreads

    /// Number of spreads (5 for 8 pages).
    var spreadCount: Int { pageCount / 2 + 1 }
    var lastSpread: Int { spreadCount - 1 }

    /// Left page of a spread, or `nil` on the cover spread.
    func leftPageIndex(ofSpread spread: Int) -> Int? {
        let index = spread * 2 - 1
        return (0..<pageCount).contains(index) ? index : nil
    }

    /// Right page of a spread, or `nil` on the back cover spread.
    func rightPageIndex(ofSpread spread: Int) -> Int? {
        let index = spread * 2
        return (0..<pageCount).contains(index) ? index : nil
    }

    /// Number of page edges drawn under a left page (max 3).
    func pagesBelow(leftPage index: Int) -> Int { min(index, 3) }

    /// Number of page edges drawn under a right page (max 3).
    func pagesBelow(rightPage index: Int) -> Int { min(pageCount - 1 - index, 3) }

    /// Horizontal offset of the book in page widths. Centers the closed zine.
    func bookOffsetFactor(forSpread spread: Int) -> CGFloat {
        if spread <= 0 { return -0.5 }
        if spread >= lastSpread { return 0.5 }
        return 0
    }

    /// Clamps the drag progress to the flips allowed from the current spread.
    ///
    /// - Parameter rawProgress: Drag distance in page widths; positive flips forward.
    /// - Returns: The progress clamped to `-1...1`.
    func clampedFlipProgress(_ rawProgress: Double) -> Double {
        var progress = rawProgress
        if spread >= lastSpread { progress = min(progress, 0) }
        if spread <= 0 { progress = max(progress, 0) }
        return max(-1, min(1, progress))
    }

    /// Whether a released drag completes the flip.
    ///
    /// - Parameters:
    ///   - progress: Progress at release.
    ///   - predictedProgress: Predicted progress from the release velocity.
    func shouldCommitFlip(progress: Double, predictedProgress: Double) -> Bool {
        let sameDirection = predictedProgress.sign == progress.sign
        return abs(progress) > 0.5 || (sameDirection && abs(predictedProgress) > 0.8)
    }

    /// Whether there is a spread in that direction.
    func canFlip(forward: Bool) -> Bool {
        (0...lastSpread).contains(spread + (forward ? 1 : -1))
    }

    /// Moves to the next (`1`) or previous (`-1`) spread.
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
        exportViewModel = ExportViewModel(document: document)
    }
}
