//
//  RGBAColor.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI
import UIKit

/// `Codable` sRGB color used by the models.
struct RGBAColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    /// Default paper color.
    static let paper = RGBAColor(red: 1, green: 1, blue: 1)
    static let black = RGBAColor(red: 0, green: 0, blue: 0)
}

// MARK: - UIKit & SwiftUI bridging

extension RGBAColor {
    /// Creates a color from a `UIColor`. Dynamic colors are resolved in light mode.
    init(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        if !resolved.getRed(&r, green: &g, blue: &b, alpha: &a) {
            var white: CGFloat = 0
            resolved.getWhite(&white, alpha: &a)
            r = white; g = white; b = white
        }
        self.init(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }

    /// Creates a color from a SwiftUI `Color`.
    init(_ color: Color) {
        self.init(UIColor(color))
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    var color: Color {
        Color(uiColor)
    }
}
