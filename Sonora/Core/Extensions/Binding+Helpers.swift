import SwiftUI

@MainActor
private final class MainActorBox<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

// MARK: - Binding Helpers

@MainActor
extension Binding {
    /// Creates a binding that transforms between optional and non-optional values
    ///
    /// Useful for form controls that require non-optional bindings but work with optional state.
    ///
    /// Example:
    /// ```swift
    /// DatePicker("Date", selection: .unwrapping($optionalDate, default: Date()))
    /// ```
    static func unwrapping<T: Sendable>(
        _ binding: Binding<T?>,
        default defaultValue: T
    ) -> Binding<T> {
        let bindingBox = MainActorBox(binding)
        let defaultValueBox = MainActorBox(defaultValue)

        return Binding<T>(
            get: {
                MainActor.assumeIsolated {
                    bindingBox.value.wrappedValue ?? defaultValueBox.value
                }
            },
            set: { newValue in
                MainActor.assumeIsolated {
                    bindingBox.value.wrappedValue = newValue
                }
            }
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
        let bindingBox = MainActorBox(binding)
        let defaultValueBox = MainActorBox(defaultValue)

        return Binding<Bool>(
            get: {
                MainActor.assumeIsolated {
                    bindingBox.value.wrappedValue != nil
                }
            },
            set: { isPresent in
                MainActor.assumeIsolated {
                    if isPresent {
                        if bindingBox.value.wrappedValue == nil {
                            bindingBox.value.wrappedValue = defaultValueBox.value()
                        }
                    } else {
                        bindingBox.value.wrappedValue = nil
                    }
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
    func keyPath<T: Sendable>(_ keyPath: WritableKeyPath<Value, T>) -> Binding<T> where Value: Sendable {
        let bindingBox = MainActorBox(self)
        let keyPathBox = MainActorBox(keyPath)

        return Binding<T>(
            get: {
                MainActor.assumeIsolated {
                    bindingBox.value.wrappedValue[keyPath: keyPathBox.value]
                }
            },
            set: { newValue in
                MainActor.assumeIsolated {
                    bindingBox.value.wrappedValue[keyPath: keyPathBox.value] = newValue
                }
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
    func map<T: Sendable>(
        get: @escaping (Value) -> T,
        set: @escaping (T) -> Value
    ) -> Binding<T> where Value: Sendable {
        let bindingBox = MainActorBox(self)
        let getBox = MainActorBox(get)
        let setBox = MainActorBox(set)

        return Binding<T>(
            get: {
                MainActor.assumeIsolated {
                    getBox.value(bindingBox.value.wrappedValue)
                }
            },
            set: { newValue in
                MainActor.assumeIsolated {
                    bindingBox.value.wrappedValue = setBox.value(newValue)
                }
            }
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
    func constant() -> Binding<Value> where Value: Sendable {
        let bindingBox = MainActorBox(self)

        return Binding<Value>(
            get: {
                MainActor.assumeIsolated {
                    bindingBox.value.wrappedValue
                }
            },
            set: { _ in }
        )
    }
}

// MARK: - Binding + Optional

@MainActor
extension Binding where Value: Equatable & ExpressibleByNilLiteral & Sendable {
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
        let bindingBox = MainActorBox(self)
        let nilValueBox = MainActorBox(nilValue)

        return Binding<Value>(
            get: {
                MainActor.assumeIsolated {
                    let current = bindingBox.value.wrappedValue
                    return current == nil ? nilValueBox.value : current
                }
            },
            set: { newValue in
                MainActor.assumeIsolated {
                    bindingBox.value.wrappedValue = (newValue == nilValueBox.value) ? nil : newValue
                }
            }
        )
    }
}
