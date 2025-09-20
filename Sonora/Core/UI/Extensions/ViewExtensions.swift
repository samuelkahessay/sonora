//
//  ViewExtensions.swift
//  Sonora
//
//  Common view extensions and helpers
//

import SwiftUI

extension View {
    /// Helper for conditional view application
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}