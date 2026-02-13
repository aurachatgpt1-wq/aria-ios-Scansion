//
//  MainAppView.swift
//  Aria_v1.0
//
//  Created by Brahim on 13/02/26.
//

import SwiftUI

struct MainAppView: View {
    @State private var selectedTab: AppTab = .chat
    
    enum AppTab {
        case chat
        case lidarScanner
    }
    
    var body: some View {
        ZStack {
            // Tab content
            Group {
                switch selectedTab {
                case .chat:
                    ContentView()
                case .lidarScanner:
                    LiDARScannerView()
                }
            }
            .transition(.opacity)
            
            // Tab bar
            VStack {
                Spacer()
                
                HStack(spacing: 0) {
                    TabBarItem(
                        icon: "bubble.left.and.bubble.right.fill",
                        label: "Chat",
                        isSelected: selectedTab == .chat,
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = .chat
                            }
                        }
                    )
                    
                    Divider()
                        .frame(height: 24)
                        .opacity(0.3)
                    
                    TabBarItem(
                        icon: "scan3d",
                        label: "LiDAR",
                        isSelected: selectedTab == .lidarScanner,
                        action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = .lidarScanner
                            }
                        }
                    )
                }
                .frame(height: 60)
                .background(
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                )
            }
        }
    }
}

struct TabBarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? .blue : .gray)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    MainAppView()
}
