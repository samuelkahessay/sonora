import SwiftUI

// MARK: - Binding Helpers

extension Binding {
    /// Creates a binding that transforms between optional and non-optional values
    ///
    /// Useful for form controls that require non-optional bindings but work with optional state.
    ///
    /// Example:
    /// ```swift
    /// DatePicker("Date", selection: .unwrapping($optionalDate, default: Date()))
    /// ```
    static func unwrapping<T>(
        _ binding: Binding<T?>,
        default defaultValue: T
    ) -> Binding<T> {
        Binding<T>(
            get: { binding.wrappedValue ?? defaultValue },
            set: { binding.wrappedValue = $0 }
        )
    }

    /// Creates a binding that maps to a derived boolean indicating presence of a value
    ///
    /// Useful for toggles that control whether an optional value is present.
    ///
    /// Example:
    /// ```swift
    /// Toggle("Include date", isOn: .isPresent($optionalDate, default: Date()))
    /// ```
    static func isPresent<T>(
        _ binding: Binding<T?>,
        default defaultValue: @autoclosure @escaping () -> T
    ) -> Binding<Bool> {
        Binding<Bool>(
            get: { binding.wrappedValue != nil },
            set: { isPresent in
                if isPresent {
                    if binding.wrappedValue == nil {
                        binding.wrappedValue = defaultValue()
                    }
                } else {
                    binding.wrappedValue = nil
                }
            }
        )
    }

    /// Creates a binding that maps to a specific keypath of the wrapped value
    ///
    /// Useful for extracting bindings to nested properties.
    ///
    /// Example:
    /// ```swift
    /// TextField("Title", text: binding.keyPath(\.title))
    /// ```
    func keyPath<T>(_ keyPath: WritableKeyPath<Value, T>) -> Binding<T> {
        Binding<T>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { newValue in
                self.wrappedValue[keyPath: keyPath] = newValue
            }
        )
    }

    /// Creates a binding that applies a transformation when reading and writing
    ///
    /// Useful for converting between different types or applying validation.
    ///
    /// Example:
    /// ```swift
    /// TextField("Amount", text: binding.map(
    ///     get: { "\($0)" },
    ///     set: { Int($0) ?? 0 }
    /// ))
    /// ```
    func map<T>(
        get: @escaping (Value) -> T,
        set: @escaping (T) -> Value
    ) -> Binding<T> {
        Binding<T>(
            get: { get(self.wrappedValue) },
            set: { self.wrappedValue = set($0) }
        )
    }

    /// Creates a read-only binding (setter is a no-op)
    ///
    /// Useful when you need to pass a binding to a component but don't want changes to propagate.
    ///
    /// Example:
    /// ```swift
    /// Toggle("Read-only", isOn: binding.constant())
    /// ```
    func constant() -> Binding<Value> {
        Binding<Value>(
            get: { self.wrappedValue },
            set: { _ in }
        )
    }
}

// MARK: - Binding + Optional

extension Binding where Value: Equatable & ExpressibleByNilLiteral {
    /// Creates a binding that treats nil as a specific sentinel value
    ///
    /// Useful for Picker or segmented controls with optional selection.
    ///
    /// Example:
    /// ```swift
    /// Picker("Choice", selection: binding.nilAs("none")) {
    ///     Text("None").tag("none")
    ///     Text("Option 1").tag("option1")
    /// }
    /// ```
    func nilAs(_ nilValue: Value) -> Binding<Value> {
        Binding<Value>(
            get: { self.wrappedValue ?? nilValue },
            set: { newValue in
                self.wrappedValue = (newValue == nilValue) ? nil : newValue
            }
        )
    }
}
