//
//  ZineSummary.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import Foundation

/// Zine info shown in the gallery.
struct ZineSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    /// `false` while the cover is blank. The gallery then shows the default cover.
    var hasCoverArt: Bool
}

/// Gallery sort options.
enum ZineSortOrder: String, CaseIterable, Identifiable, Sendable {
    case modified, created, title

    var id: String { rawValue }

    /// Name shown in the sort menu.
    var displayName: String {
        switch self {
        case .modified: return "Editadas recentemente"
        case .created: return "Criadas recentemente"
        case .title: return "Nome"
        }
    }

    /// Sorts summaries according to this order.
    ///
    /// - Parameter summaries: Unsorted summaries.
    /// - Returns: The summaries in display order.
    func sorted(_ summaries: [ZineSummary]) -> [ZineSummary] {
        switch self {
        case .modified:
            return summaries.sorted { $0.modifiedAt > $1.modifiedAt }
        case .created:
            return summaries.sorted { $0.createdAt > $1.createdAt }
        case .title:
            return summaries.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }
}
