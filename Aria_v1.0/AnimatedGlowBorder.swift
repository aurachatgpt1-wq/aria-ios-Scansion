//
//  AnimatedGlowBorder.swift
//  Aria_v1.0
//
//  Created by Giovanni Michele on 18/12/25.
//


import SwiftUI

struct AnimatedGlowBorder: View {
    var cornerRadius: CGFloat = 32
    var lineWidth: CGFloat = 3.2          // più spesso
    var isActive: Bool

    @State private var angle: Double = 0

    private var gradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: Color.cyan.opacity(0.05), location: 0.00),
                .init(color: Color.cyan.opacity(0.55), location: 0.18),
                .init(color: Color.blue.opacity(0.35), location: 0.50),
                .init(color: Color.cyan.opacity(0.55), location: 0.82),
                .init(color: Color.cyan.opacity(0.05), location: 1.00)
            ]),
            center: .center,
            startAngle: .degrees(angle),
            endAngle: .degrees(angle + 360)
        )
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            // bordo base leggero
            shape
                .stroke(.white.opacity(0.12), lineWidth: 1)

            // glow animato (solo active)
            if isActive {
                // 1) stroke principale (visibile)
                shape
                    .strokeBorder(gradient, lineWidth: lineWidth)
                    .opacity(0.95)

                // 2) glow medio (più spesso + blur)
                shape
                    .strokeBorder(gradient, lineWidth: lineWidth + 4)
                    .blur(radius: 10)
                    .opacity(0.55)
                    .shadow(color: .cyan.opacity(0.22), radius: 18)

                // 3) glow molto diffuso (halo esterno)
                shape
                    .strokeBorder(gradient, lineWidth: lineWidth + 10)
                    .blur(radius: 22)
                    .opacity(0.28)
                    .shadow(color: .blue.opacity(0.16), radius: 30)
            }
        }
        .compositingGroup()
        .opacity(isActive ? 1 : 0)
        .onAppear { startIfNeeded() }
        .onChange(of: isActive) { _, _ in startIfNeeded() }
    }

    private func startIfNeeded() {
        guard isActive else { return }
        angle = 0
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            angle = 360
        }
    }
}



