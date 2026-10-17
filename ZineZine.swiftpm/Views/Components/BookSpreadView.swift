//
//  BookSpreadView.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

/// Open zine with a page flip on drag. The page rotates around the spine with
/// `rotation3DEffect` and shows its back after 90°. Spread logic is in
/// ``ReaderViewModel``; the view only keeps the animation progress.
struct BookSpreadView: View {
    let viewModel: ReaderViewModel

    /// `-1...1`. Positive flips forward, negative flips backward.
    @State private var progress: Double = 0
    @State private var isSettling = false

    /// Tilt of the open pages, in degrees.
    private let tilt: Double = 9
    private let aspect = ZineFormat.pageSize.width / ZineFormat.pageSize.height

    private var spread: Int { viewModel.spread }
    private func leftIndex(_ spread: Int) -> Int? { viewModel.leftPageIndex(ofSpread: spread) }
    private func rightIndex(_ spread: Int) -> Int? { viewModel.rightPageIndex(ofSpread: spread) }

    var body: some View {
        GeometryReader { geometry in
            let pageWidth = min(geometry.size.width * 0.9 / 2, geometry.size.height * 0.92 * aspect)
            let pageHeight = pageWidth / aspect
            let target = progress > 0 ? spread + 1 : (progress < 0 ? spread - 1 : spread)
            let offset = pageWidth * lerp(viewModel.bookOffsetFactor(forSpread: spread),
                                          viewModel.bookOffsetFactor(forSpread: target),
                                          abs(progress))

            ZStack {
                HStack(spacing: 0) {
                    leftSide(width: pageWidth, height: pageHeight)
                    rightSide(width: pageWidth, height: pageHeight)
                }
                leaf(width: pageWidth, height: pageHeight)
            }
            .frame(width: pageWidth * 2, height: pageHeight)
            .offset(x: offset)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(pageWidth: pageWidth))
            .onTapGesture { location in
                guard !isSettling else { return }
                flip(forward: location.x > geometry.size.width / 2)
            }
        }
    }

    // MARK: - Static sides

    private func leftSide(width: CGFloat, height: CGFloat) -> some View {
        let index = progress < 0 ? leftIndex(spread - 1) : leftIndex(spread)
        return pageFace(index, side: .left)
            .frame(width: width, height: height)
            .background(alignment: .trailing) {
                if let index { stack(count: viewModel.pagesBelow(leftPage: index), side: .left, width: width) }
            }
            .rotation3DEffect(.degrees(index == nil ? 0 : tilt), axis: (0, 1, 0), anchor: .trailing, perspective: 0.35)
    }

    private func rightSide(width: CGFloat, height: CGFloat) -> some View {
        let index = progress > 0 ? rightIndex(spread + 1) : rightIndex(spread)
        return pageFace(index, side: .right)
            .frame(width: width, height: height)
            .background(alignment: .leading) {
                if let index { stack(count: viewModel.pagesBelow(rightPage: index), side: .right, width: width) }
            }
            .rotation3DEffect(.degrees(index == nil ? 0 : -tilt), axis: (0, 1, 0), anchor: .leading, perspective: 0.35)
    }

    /// Page edges under a page.
    private func stack(count: Int, side: PageSide, width: CGFloat) -> some View {
        ZStack {
            ForEach((0..<count).reversed(), id: \.self) { k in
                let step = CGFloat(k + 1)
                side.shape
                    .fill(Color(white: 0.8 - Double(k) * 0.03))
                    .frame(width: width)
                    .padding(.vertical, 6 * step)
                    .offset(x: side == .left ? -9 * step : 9 * step)
                    .shadow(color: .black.opacity(0.15), radius: 2)
            }
        }
    }

    // MARK: - Turning leaf

    @ViewBuilder
    private func leaf(width: CGFloat, height: CGFloat) -> some View {
        if progress > 0 {
            // Right page turning to the left.
            let angle = -tilt - (180 - 2 * tilt) * progress
            HStack(spacing: 0) {
                Color.clear.frame(width: width, height: height)
                leafFace(front: rightIndex(spread), back: leftIndex(spread + 1),
                         frontSide: .right, angle: angle)
                    .frame(width: width, height: height)
                    .rotation3DEffect(.degrees(angle), axis: (0, 1, 0), anchor: .leading, perspective: 0.35)
            }
        } else if progress < 0 {
            let angle = tilt + (180 - 2 * tilt) * -progress
            HStack(spacing: 0) {
                leafFace(front: leftIndex(spread), back: rightIndex(spread - 1),
                         frontSide: .left, angle: angle)
                    .frame(width: width, height: height)
                    .rotation3DEffect(.degrees(angle), axis: (0, 1, 0), anchor: .trailing, perspective: 0.35)
                Color.clear.frame(width: width, height: height)
            }
        }
    }

    @ViewBuilder
    private func leafFace(front: Int?, back: Int?, frontSide: PageSide, angle: Double) -> some View {
        let showsBack = abs(angle) > 90
        // Darker while the page is turning.
        let shade = 0.35 * (1 - abs(cos(angle * .pi / 180)))
        Group {
            if showsBack {
                pageFace(back, side: frontSide.opposite)
                    .scaleEffect(x: -1)
            } else {
                pageFace(front, side: frontSide)
            }
        }
        .overlay(Color.black.opacity(shade).allowsHitTesting(false))
        .clipShape(showsBack ? frontSide.opposite.mirroredShape : frontSide.shape)
    }

    // MARK: - Page

    @ViewBuilder
    private func pageFace(_ index: Int?, side: PageSide) -> some View {
        if let index {
            ZStack {
                Color.blankPaper
                if let image = viewModel.pageImage(at: index) {
                    Image(uiImage: image)
                        .resizable()
                }
                // Shadow near the spine.
                LinearGradient(colors: [.black.opacity(0.18), .clear],
                               startPoint: side == .left ? .trailing : .leading,
                               endPoint: side == .left ? UnitPoint(x: 0.88, y: 0.5) : UnitPoint(x: 0.12, y: 0.5))
            }
            .clipShape(side.shape)
            .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
        } else {
            Color.clear
        }
    }

    // MARK: - Gestures

    private func dragGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isSettling else { return }
                progress = viewModel.clampedFlipProgress(Double(-value.translation.width / pageWidth))
            }
            .onEnded { value in
                guard !isSettling, progress != 0 else { return }
                let predicted = Double(-value.predictedEndTranslation.width / pageWidth)
                let commit = viewModel.shouldCommitFlip(progress: progress, predictedProgress: predicted)
                settle(commit: commit, direction: progress > 0 ? 1 : -1)
            }
    }

    private func flip(forward: Bool) {
        guard viewModel.canFlip(forward: forward) else { return }
        let direction = forward ? 1 : -1
        progress = 0.001 * Double(direction)
        settle(commit: true, direction: direction)
    }

    private func settle(commit: Bool, direction: Int) {
        isSettling = true
        withAnimation(.easeOut(duration: commit ? 0.45 : 0.25)) {
            progress = commit ? Double(direction) : 0
        } completion: {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if commit { viewModel.completeFlip(direction: direction) }
                progress = 0
            }
            isSettling = false
        }
    }

    // MARK: - Geometry

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        a + (b - a) * CGFloat(t)
    }
}

/// Which half of a spread a page sits on.
enum PageSide {
    case left, right

    var opposite: PageSide { self == .left ? .right : .left }

    /// Rounded outer corners, straight spine.
    var shape: UnevenRoundedRectangle {
        switch self {
        case .left:
            return UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22,
                                          bottomTrailingRadius: 0, topTrailingRadius: 0)
        case .right:
            return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                          bottomTrailingRadius: 22, topTrailingRadius: 22)
        }
    }

    /// Shape of a back face mirrored by `scaleEffect(x: -1)`.
    var mirroredShape: UnevenRoundedRectangle { opposite.shape }
}

// MARK: - Previews

#Preview(traits: .landscapeLeft) {
    BookSpreadView(viewModel: ReaderViewModel(document: PreviewData.document()))
        .padding(60)
        .background(DeskBackground(style: .reader))
}
