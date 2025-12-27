//
//  TestView.swift
//  Clipboard
//
//  Created by crown on 2025/12/26.
//

import SwiftUI

// MARK: - Model

struct DemoCard: Identifiable {
    let id = UUID()
    let title: String
    let color: Color
}

// MARK: - Card View

struct DemoCardView: View {
    let card: DemoCard

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(card.color.gradient)
            .overlay(
                VStack {
                    Spacer()
                    Text(card.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .padding()
                }
            )
            .shadow(radius: 6, y: 4)
    }
}

// MARK: - Horizontal Peek Carousel

struct HorizontalPeekCarousel: View {
    private let cardWidth: CGFloat = 260
    private let cardHeight: CGFloat = 180
    private let spacing: CGFloat = 20

    let cards: [DemoCard]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: spacing) {
                ForEach(cards) { card in
                    DemoCardView(card: card)
                        .frame(width: cardWidth, height: cardHeight)
                        .visualEffect { content, proxy in
                            let frame = proxy.frame(in: .scrollView)
                            let distance = abs(frame.midX)

                            let progress = min(
                                distance / (cardWidth + spacing),
                                1
                            )

                            let opacity = (1 - progress * 0.4)

                            return
                                content
                                    .scaleEffect(1 - progress * 0.12)
                                    .opacity(opacity)
                                    .offset(y: progress * 14)
                        }
                }
            }
            // Padding ensures first/last cards can peek
            .padding(.horizontal, (cardWidth + spacing) / 2)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
    }
}

// MARK: - Demo ContentView

struct TestContentView: View {
    private let cards: [DemoCard] = [
        .init(title: "Explore", color: .blue),
        .init(title: "Music", color: .purple),
        .init(title: "Games", color: .orange),
        .init(title: "Design", color: .green),
        .init(title: "Develop", color: .red),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Horizontal Peek Carousel")
                .font(.largeTitle.bold())
                .padding(.horizontal)

            HorizontalPeekCarousel(cards: cards)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    TestContentView()
        .frame(width: 900, height: 500)
}
