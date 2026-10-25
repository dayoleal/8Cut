//
//  ChromeStyle.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

// MARK: - Colors

/// App colors.
extension Color {
    static let acidGreen = Color("acidGreen")
    static let chromeDark = Color("darkGray")
    static let chromeMedium = Color("mediumGray")
    /// Selection highlight in the page drawer.
    static let chromeHighlight = Color(white: 0.4)
    /// Paper color of empty pages in the reader.
    static let blankPaper = Color(white: 0.86)
}

// MARK: - Icons & buttons

/// Circular icon used as the label of toolbar buttons and menus.
struct ChromeIcon: View {
    let systemName: String
    /// Inverts the colors for the "on" state.
    var isActive: Bool = false
    /// Diameter; `nil` uses 60 pt scaled by `deviceScale`.
    var size: CGFloat? = nil

    private var diameter: CGFloat { size ?? 60 * deviceScale }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: diameter * 0.4, weight: .semibold))
            .foregroundStyle(isActive ? Color.chromeDark : Color.acidGreen)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(isActive ? Color.acidGreen : Color.chromeMedium))
            .contentShape(Circle())
    }
}

/// Circular icon button.
struct ChromeIconButton: View {
    let systemName: String
    var isActive: Bool = false
    var isEnabled: Bool = true
    /// Diameter; `nil` uses the scaled default of ``ChromeIcon``.
    var size: CGFloat? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ChromeIcon(systemName: systemName, isActive: isActive, size: size)
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Back button of the reader.
struct ChromeBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ChromeIcon(systemName: "chevron.left")
                .padding(8 * deviceScale)
                .background(Circle().fill(Color.chromeDark))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Voltar")
    }
}

// MARK: - Containers

extension View {
    /// Dark capsule around a group of buttons.
    ///
    /// - Parameter padding: Space between the capsule and its buttons.
    func chromeCapsule(padding: CGFloat = 10) -> some View {
        self
            .padding(padding * deviceScale)
            .background(Capsule().fill(Color.chromeDark))
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
    }
}

/// Tab of a drawer on the right edge of the editor (pages, layers).
/// Shows the title only while closed.
struct DrawerTab: View {
    let systemName: String
    let title: String
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4 * deviceScale) {
                Image(systemName: systemName)
                    .font(.system(size: 18 * deviceScale, weight: .semibold))
                if !isOpen {
                    Text(title)
                        .font(.system(size: 12 * deviceScale, weight: .semibold))
                }
            }
            .foregroundStyle(Color.acidGreen)
            .frame(width: (isOpen ? 48 : 70) * deviceScale, height: (isOpen ? 52 : 64) * deviceScale)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 16 * deviceScale,
                                       bottomLeadingRadius: isOpen ? 0 : 16 * deviceScale)
                    .fill(Color.chromeDark)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOpen ? "Aberto" : "Fechado")
    }
}

/// Scales the card down while pressed.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 10) {
            ChromeIconButton(systemName: "house") {}
            ChromeIconButton(systemName: "photo.badge.plus") {}
            ChromeIconButton(systemName: "pencil.and.scribble", isActive: true) {}
            ChromeIconButton(systemName: "square.and.arrow.up", isEnabled: false) {}
        }
        .chromeCapsule()
        ChromeBackButton {}
    }
    .padding(40)
    .background(DeskBackground(style: .reader))
}
