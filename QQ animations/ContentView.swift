//
//  ContentView.swift
//  QQ animations
//
//  Created by Rhett Wilhoit on 3/28/25.
//

import SwiftUI
import UIKit

// UIKit extension to get safe area insets
extension UIApplication {
    static var safeAreaInsets: UIEdgeInsets {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.windows.first?.safeAreaInsets ?? .zero
    }
}

struct ContentView: View {
    // States for the overlay positions
    @State private var topOverlayOffset: CGFloat = 0
    @State private var bottomOverlayOffset: CGFloat = 0
    
    // Track which overlay is active (being dragged/open)
    @State private var topOverlayActive: Bool = false
    @State private var bottomOverlayActive: Bool = false
    
    // Constants for overlay sizes
    let topBarHeight: CGFloat = 50
    let bottomBarHeight: CGFloat = 50
    let cardHeight: CGFloat = 300
    
    // Defined colors for better consistency
    let topHandleColor = Color(red: 0.0, green: 0.4, blue: 0.8) // Deeper blue
    let topOverlayColor = Color(red: 0.1, green: 0.5, blue: 0.9) // Lighter blue
    let bottomHandleColor = Color(red: 0.5, green: 0.0, blue: 0.7) // Deep purple
    let bottomOverlayColor = Color(red: 0.6, green: 0.1, blue: 0.8) // Lighter purple
    
    // Get the safe area insets directly from UIKit
    var safeAreaTop: CGFloat {
        UIApplication.safeAreaInsets.top
    }
    
    var safeAreaBottom: CGFloat {
        UIApplication.safeAreaInsets.bottom
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main background
                Color.white.ignoresSafeArea()
                
                // Main content stack
                VStack(spacing: 0) {
                    // Top bar with correct positioning
                    ZStack(alignment: .top) {
                        // Safe area spacer
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: safeAreaTop)
                        
                        // Top bar positioned below safe area - make transparent but keep for layout
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: topBarHeight)
                            .offset(y: safeAreaTop)
                    }
                    .frame(height: safeAreaTop + topBarHeight)
                    
                    Spacer()
                    
                    // Card container
                    ZStack {
                        // Card background
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: cardHeight)
                            .cornerRadius(10)
                            .padding(.horizontal)
                        
                        // Card content
                        Text("Question text will appear here")
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    
                    Spacer()
                    
                    // Bottom bar with correct positioning
                    ZStack(alignment: .bottom) {
                        // Bottom bar positioned above safe area - make transparent but keep for layout
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: bottomBarHeight)
                        
                        // Safe area spacer
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: safeAreaBottom)
                            .offset(y: bottomBarHeight)
                    }
                    .frame(height: safeAreaBottom + bottomBarHeight)
                }
                
                // MARK: - Top Overlay
                
                // Top Overlay with body and handle
                VStack(spacing: 0) {
                    // Top overlay body
                    Rectangle()
                        .fill(topOverlayColor)
                        .frame(height: geometry.size.height - topBarHeight)
                    
                    // Top overlay handle - draggable
                    Rectangle()
                        .fill(topHandleColor)
                        .frame(height: topBarHeight)
                        .contentShape(Rectangle()) // Ensure entire handle is tappable
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Activate this overlay while dragging
                                    topOverlayActive = true
                                    
                                    // Calculate new offset based on drag, with limits
                                    let newOffset = topOverlayOffset + value.translation.height
                                    // Calculate full slide distance to position precisely at bottom bar
                                    let maxOffset = geometry.size.height - (safeAreaTop + topBarHeight) - safeAreaBottom
                                    topOverlayOffset = min(maxOffset, max(0, newOffset))
                                }
                                .onEnded { value in
                                    // Snap to fully open or closed based on current position
                                    let threshold = (geometry.size.height - topBarHeight - safeAreaTop) / 2
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if topOverlayOffset > threshold {
                                            // Snap to fully open - positioned at bottom bar
                                            // Calculate full slide distance to position precisely at bottom bar
                                            let fullSlideDistance = geometry.size.height - (safeAreaTop + topBarHeight) - safeAreaBottom
                                            topOverlayOffset = fullSlideDistance
                                            // Keep active when open
                                            topOverlayActive = true
                                        } else {
                                            // Snap to closed
                                            topOverlayOffset = 0
                                            // Deactivate when closed
                                            topOverlayActive = false
                                        }
                                    }
                                }
                        )
                }
                .offset(y: -geometry.size.height + topBarHeight + safeAreaTop + topOverlayOffset)
                .zIndex(topOverlayActive ? 2 : 0)
                .animation(.easeInOut(duration: 0.3), value: topOverlayOffset)
                
                // MARK: - Bottom Overlay
                
                // Bottom Overlay with handle and body
                VStack(spacing: 0) {
                    // Bottom overlay handle - draggable
                    Rectangle()
                        .fill(bottomHandleColor)
                        .frame(height: bottomBarHeight)
                        .contentShape(Rectangle()) // Ensure entire handle is tappable
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Activate this overlay while dragging
                                    bottomOverlayActive = true
                                    
                                    // Calculate new offset based on drag, with limits
                                    let newOffset = bottomOverlayOffset - value.translation.height
                                    // Calculate full slide distance to position precisely at top bar
                                    let maxOffset = geometry.size.height - (safeAreaBottom + bottomBarHeight) - safeAreaTop
                                    bottomOverlayOffset = min(maxOffset, max(0, newOffset))
                                }
                                .onEnded { value in
                                    // Snap to fully open or closed based on current position
                                    let threshold = (geometry.size.height - bottomBarHeight - safeAreaBottom) / 2
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if bottomOverlayOffset > threshold {
                                            // Snap to fully open - positioned at top bar
                                            // Calculate full slide distance to position precisely at top bar
                                            let fullSlideDistance = geometry.size.height - (safeAreaBottom + bottomBarHeight) - safeAreaTop
                                            bottomOverlayOffset = fullSlideDistance
                                            // Keep active when open
                                            bottomOverlayActive = true
                                        } else {
                                            // Snap to closed
                                            bottomOverlayOffset = 0
                                            // Deactivate when closed
                                            bottomOverlayActive = false
                                        }
                                    }
                                }
                        )
                    
                    // Bottom overlay body
                    Rectangle()
                        .fill(bottomOverlayColor)
                        .frame(height: geometry.size.height - bottomBarHeight)
                }
                .offset(y: geometry.size.height - bottomBarHeight - safeAreaBottom - bottomOverlayOffset)
                .zIndex(bottomOverlayActive ? 2 : 1)
                .animation(.easeInOut(duration: 0.3), value: bottomOverlayOffset)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
