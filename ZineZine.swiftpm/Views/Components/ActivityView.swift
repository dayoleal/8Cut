//
//  ActivityView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI
import UIKit

/// The system share sheet (`UIActivityViewController`).
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Images to share, used with `.sheet(item:)`.
struct ShareItems: Identifiable {
    let id = UUID()
    let images: [UIImage]
}

// MARK: - Previews

#Preview {
    ActivityView(items: ["8-Cut"])
}
