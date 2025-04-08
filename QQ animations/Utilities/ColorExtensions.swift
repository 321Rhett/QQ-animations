import SwiftUI

// Color extension for app colors
extension Color {
    // Main UI colors
    static let topHandle = Color(red: 0.0, green: 0.4, blue: 0.8) // Deeper blue
    static let topOverlay = Color(red: 0.1, green: 0.5, blue: 0.9) // Lighter blue
    static let bottomHandle = Color(red: 0.5, green: 0.0, blue: 0.7) // Deep purple
    static let bottomOverlay = Color(red: 0.6, green: 0.1, blue: 0.8) // Lighter purple
    
    // Action symbols colors
    static let skipSymbol = Color(red: 0.6, green: 0.6, blue: 0.6) // Light grey
    static let completeSymbol = Color(red: 0.2, green: 0.6, blue: 0.2) // Green
    static let favoriteSymbol = Color(red: 0.8, green: 0.7, blue: 0.0) // Gold
    static let hiddenSymbol = Color(red: 0.7, green: 0.0, blue: 0.0) // Dark red
    
    // Status colors
    static let favoriteHandle = Color(red: 0.8, green: 0.7, blue: 0.0) // Gold
    static let favoriteOverlay = Color(red: 0.9, green: 0.8, blue: 0.2) // Light gold
    static let hiddenHandle = Color(red: 0.7, green: 0.0, blue: 0.0) // Dark red
    static let hiddenOverlay = Color(red: 0.8, green: 0.1, blue: 0.1) // Light red
    
    // Filter UI colors
    static let aqua = Color(red: 0, green: 0.8, blue: 0.8) // Aqua for inclusion highlight
    static let excludeRed = Color(red: 0.7, green: 0.0, blue: 0.0) // Red for exclusion highlight
    
    // Filagree colors
    static let filagree = Color(red: 0.6, green: 0.6, blue: 0.6) // Light grey (same as skip symbol)
    static let appBackground = Color(red: 0.12, green: 0.12, blue: 0.12) // Dark grey (almost black)
} 