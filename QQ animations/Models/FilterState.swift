import Foundation

enum FilterState {
    case none      // Default, no filtering applied
    case include   // Include items matching the filter
    case exclude   // Exclude items matching the filter
} 