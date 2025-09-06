import UIKit

// Check for New York fonts
print("=== Font Diagnostic ===")
for family in UIFont.familyNames.sorted() where family.contains("New") {
    print("Family:", family)
    for name in UIFont.fontNames(forFamilyName: family) { 
        print("  →", name) 
    }
}

// Also check all serif fonts
print("\n=== All Serif-Related Fonts ===")
for family in UIFont.familyNames.sorted() where family.lowercased().contains("serif") || family.lowercased().contains("york") {
    print("Family:", family)
    for name in UIFont.fontNames(forFamilyName: family) { 
        print("  →", name) 
    }
}
