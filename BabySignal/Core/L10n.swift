import Foundation

/// Native bundle localization shared by the app and the Live Activity extension.
enum L10n {
  static func text(_ key: String, bundle: Bundle = .main) -> String {
    bundle.localizedString(forKey: key, value: key, table: "Localizable")
  }

  static func format(_ key: String, _ value: String, bundle: Bundle = .main) -> String {
    String(format: text(key, bundle: bundle), locale: Locale.current, value)
  }

  /// Fixed record descriptions follow the current language without rewriting stored history.
  /// System-generated error details remain in the language in which iOS supplied them.
  static func storedText(_ value: String, bundle: Bundle = .main) -> String {
    let direct = text(value, bundle: bundle)
    if direct != value { return direct }
    let table: [String: String]
    let resourceRoot = bundle.bundleURL.pathExtension == "lproj"
      ? bundle.bundleURL.deletingLastPathComponent() : (bundle.resourceURL ?? bundle.bundleURL)
    if let english = Bundle(url: resourceRoot.appendingPathComponent("en.lproj")),
       let url = english.url(forResource: "Localizable", withExtension: "strings"),
       let dictionary = NSDictionary(contentsOf: url) as? [String: String] {
      table = dictionary
    } else if let url = bundle.url(forResource: "Localizable", withExtension: "strings"),
              let dictionary = NSDictionary(contentsOf: url) as? [String: String] {
      table = dictionary
    } else { return value }
    for (key, english) in table {
      if value == english { return text(key, bundle: bundle) }
      guard key.contains("%@") else { continue }
      for prefix in [key, english].map({ String($0.components(separatedBy: "%@")[0]) }) {
        if value.hasPrefix(prefix) {
          return format(key, String(value.dropFirst(prefix.count)), bundle: bundle)
        }
      }
    }
    return value
  }
}
