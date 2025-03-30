//
//  QQ_animationsApp.swift
//  QQ animations
//
//  Created by Rhett Wilhoit on 3/28/25.
//

import SwiftUI

@main
struct QQ_animationsApp: App {
    @State private var isShowingSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                NavigationView {
                    HomeView()
                }
                .opacity(isShowingSplash ? 0 : 1)
                
                if isShowingSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                        .onAppear {
                            // Transition to HomeView after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation(.easeInOut(duration: 0.7)) {
                                    isShowingSplash = false
                                }
                            }
                        }
                }
            }
        }
    }
}
