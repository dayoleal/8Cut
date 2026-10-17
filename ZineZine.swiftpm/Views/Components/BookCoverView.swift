//
//  BookCoverView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// A closed zine as shown in the gallery: straight spine on the left, rounded
struct BookCoverView: View {
    let title: String
    /// Rendered cover. `nil` shows ``DefaultCoverArt``.
    let image: UIImage?
    /// Forces ``DefaultCoverArt`` even when an image exists (blank cover).
    var showsDefaultCover: Bool = false

    private let coverShape = UnevenRoundedRectangle(
        topLeadingRadius: 2, bottomLeadingRadius: 2,
        bottomTrailingRadius: 24, topTrailingRadius: 24
    )

    var body: some View {
        coverFace
            .aspectRatio(ZineFormat.pageAspectRatio, contentMode: .fit)
            .clipShape(coverShape)
            .background { pageEdges }
            .padding(.trailing, 14)
            .shadow(color: .black.opacity(0.35), radius: 10, x: 4, y: 8)
    }

    @ViewBuilder
    private var coverFace: some View {
        if let image, !showsDefaultCover {
            Image(uiImage: image)
                .resizable()
        } else {
            DefaultCoverArt(title: title)
        }
    }

    /// Two inside pages peeking out of the right edge.
    private var pageEdges: some View {
        ZStack {
            coverShape
                .fill(Color(white: 0.78))
                .padding(.vertical, 12)
                .offset(x: 14)
            coverShape
                .fill(Color(white: 0.88))
                .padding(.vertical, 6)
                .offset(x: 7)
        }
    }
}

/// Cover of a zine whose cover page is still blank: red with lettered title.
struct DefaultCoverArt: View {
    let title: String

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size.width * 0.28
            ZStack(alignment: .bottomTrailing) {
                Color(red: 0.64, green: 0.11, blue: 0.12)
                ZStack {
                    lettering(size: size)
                        .foregroundStyle(.black)
                        .offset(x: size * 0.06, y: size * 0.05)
                    lettering(size: size)
                        .foregroundStyle(Color(red: 1, green: 0.33, blue: 0.82))
                }
                .rotationEffect(.degrees(-14))
                .padding(geometry.size.width * 0.06)
            }
        }
    }

    private func lettering(size: CGFloat) -> some View {
        Text(title.isEmpty ? "ZINE" : title.uppercased())
            .font(.custom("MarkerFelt-Wide", size: size))
            .lineLimit(2)
            .minimumScaleFactor(0.3)
            .multilineTextAlignment(.trailing)
    }
}

// MARK: - Previews

#Preview {
    HStack(spacing: 40) {
        BookCoverView(title: "Zine", image: nil)
        BookCoverView(title: "Minha revista", image: nil, showsDefaultCover: true)
    }
    .frame(height: 360)
    .padding(40)
    .background(DeskBackground(style: .gallery))
}
