//
//  LoadingWaveView.swift
//  Aria_v1.0
//
//  Created by Giovanni Michele on 11/12/25.
//

import SwiftUI

struct LoadingWaveView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { i in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 7, height: 7)
                    .scaleEffect(scale(for: i))
                    .opacity(0.85)
            }
            Text("Aria is Thinking...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.leading, 6)
        }
        .padding(.vertical, 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    private func scale(for index: Int) -> CGFloat {
        
        let offset = CGFloat(index) * 0.18
        let t = (phase + offset).truncatingRemainder(dividingBy: 1)
        
        let v = 1 - abs(2 * t - 1)
        return 0.85 + v * 0.55
    }
}
