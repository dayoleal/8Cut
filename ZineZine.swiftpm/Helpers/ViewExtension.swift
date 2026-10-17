//
//  ViewExtension.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI
import UIKit

// MARK: - Window size

extension View {
    /// Width of the app window, a scene-based replacement for `UIScreen.main.bounds.width`.
    ///
    /// Uses the key window of the first `UIWindowScene`, so it also follows Split View and
    /// Stage Manager; falls back to the screen bounds, and to `.zero` without a scene.
    var width: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return .zero
        }
        return windowScene.keyWindow?.bounds.width ?? windowScene.screen.bounds.size.width
    }

    /// Height of the app window, a scene-based replacement for `UIScreen.main.bounds.height`.
    var height: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return .zero
        }
        return windowScene.keyWindow?.bounds.height ?? windowScene.screen.bounds.size.height
    }

    /// Size factor relative to the 11-inch iPad, the size the layout was designed on.
    ///
    /// Based on the window's shorter side (834 pt on the 11-inch iPad), so it stays the same
    /// when the device rotates: `1` on the 11-inch, about `0.89` on the iPad mini and
    /// `1.23` on the 13-inch. Multiply design measurements by it.
    var deviceScale: CGFloat {
        let shorterSide = min(width, height)
        return shorterSide > 0 ? shorterSide / 834 : 1
    }
}
