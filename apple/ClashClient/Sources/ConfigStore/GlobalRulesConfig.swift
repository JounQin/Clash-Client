import ClashClientKit
import Foundation

/// Rules that every configuration receives before its own rules.
///
/// They live outside profiles and outside rule schemes on purpose: a profile
/// that follows a built-in scheme can be refreshed without losing them, and a
/// scheme can be updated without carrying a private copy of them.
struct GlobalRulesConfig: Codable, Equatable {
    static let defaultsKey = "config.globalRules.v1"

    static let didChangeNotification = Notification.Name("ClashGlobalRulesDidChange")

    var isEnabled: Bool
    var rules: [String]

    init(isEnabled: Bool = true, rules: [String] = []) {
        self.isEnabled = isEnabled
        self.rules = rules
    }

    var isEmpty: Bool { rules.isEmpty }

    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: ClashAppIdentifiers.appGroup) ?? .standard
    }

    static func load(from defaults: UserDefaults = appGroupDefaults) -> GlobalRulesConfig {
        guard let data = defaults.data(forKey: defaultsKey),
              let stored = try? JSONDecoder().decode(GlobalRulesConfig.self, from: data)
        else { return GlobalRulesConfig() }
        return stored
    }

    static func save(_ config: GlobalRulesConfig, in defaults: UserDefaults = appGroupDefaults) {
        var cleaned = config
        cleaned.rules = normalized(config.rules)
        guard let data = try? JSONEncoder().encode(cleaned) else { return }
        defaults.set(data, forKey: defaultsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: defaults)
    }

    static func normalized(_ rules: [String]) -> [String] {
        var seen: Set<String> = []
        return rules
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// Prepends the stored rules to a generated configuration.
    ///
    /// Rules whose policy the configuration does not define are left out for it
    /// instead of failing its build, the same way personal rules are handled.
    func merging(into yaml: String) throws -> String {
        guard isEnabled, !rules.isEmpty else { return yaml }
        var kept = try ProfileRuntimeConfigBuilder.resolvedFallbackTargets(rules, mergedInto: yaml)
        kept = ProfileRuntimeConfigBuilder.droppingUnknownTargets(kept, mergedInto: yaml).kept
        guard !kept.isEmpty else { return yaml }
        let payload = OrderedJSON.object([
            (key: "appendRules", value: .array(kept.map(OrderedJSON.string))),
            (key: "prependRules", value: .scalar("true")),
        ])
        return try ConfigTransforms.mergeOverride(raw: yaml, overrideJSON: payload.serialized())
    }
}
