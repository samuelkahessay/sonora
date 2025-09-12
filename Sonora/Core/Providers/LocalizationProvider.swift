import Foundation

public protocol LocalizationProvider: Sendable {
    func localizedString(_ key: String, locale: Locale) -> String
}

public struct DefaultLocalizationProvider: LocalizationProvider, Sendable {
    public init() {}

    public func localizedString(_ key: String, locale: Locale) -> String {
        // Locale parameter currently not used for bundle selection; keep to satisfy protocol.
        _ = locale
        // Use main bundle for now. In future, support custom tables/bundles.
        return NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
    }
}
