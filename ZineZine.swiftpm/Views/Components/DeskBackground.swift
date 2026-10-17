//
//  DeskBackground.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// Zoom, position, brightness and saturation of the `Background` image per screen.
enum DeskBackgroundStyle {
    /// Zoomed on the upper center, lighter.
    case gallery
    /// Medium zoom, lighter.
    case reader
    /// Full image, darker.
    case editor

    var scale: CGFloat {
        switch self {
        case .gallery: return 1.7
        case .reader: return 1.45
        case .editor: return 1.0
        }
    }

    var anchor: UnitPoint {
        switch self {
        case .gallery: return UnitPoint(x: 0.42, y: 0.18)
        case .reader: return UnitPoint(x: 0.38, y: 0.32)
        case .editor: return .center
        }
    }

    var brightness: Double {
        switch self {
        case .gallery: return 0.14
        case .reader: return 0.1
        case .editor: return -0.06
        }
    }

    var saturation: Double {
        switch self {
        case .gallery: return 1.05
        case .reader: return 1.05
        case .editor: return 0.9
        }
    }
}

/// Background image of the screens.
struct DeskBackground: View {
    var style: DeskBackgroundStyle

    var body: some View {
        GeometryReader { geometry in
            Image("Background")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scaleEffect(style.scale, anchor: style.anchor)
                .saturation(style.saturation)
                .brightness(style.brightness)
                .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Gallery") {
    DeskBackground(style: .gallery)
}

#Preview("Reader") {
    DeskBackground(style: .reader)
}

#Preview("Editor", traits: .landscapeLeft) {
    DeskBackground(style: .editor)
}
