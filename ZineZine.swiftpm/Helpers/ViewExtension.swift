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
    /// Window width. Replaces `UIScreen.main.bounds.width` and follows Split View.
    var width: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return .zero
        }
        return windowScene.keyWindow?.bounds.width ?? windowScene.screen.bounds.size.width
    }

    /// Window height. Replaces `UIScreen.main.bounds.height`.
    var height: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return .zero
        }
        return windowScene.keyWindow?.bounds.height ?? windowScene.screen.bounds.size.height
    }

    /// Scale relative to the 11-inch iPad, based on the shorter side of the window
    /// (834 pt). Does not change with rotation.
    var deviceScale: CGFloat {
        let shorterSide = min(width, height)
        return shorterSide > 0 ? shorterSide / 834 : 1
    }
}
