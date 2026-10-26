import ClashClientUI
import SwiftUI

/// Editor for the app-level rules that every configuration receives first.
struct GlobalRulesView: View {
    var restageRuntime: () -> Void = {}

    @State private var isEnabled = GlobalRulesConfig.load().isEnabled
    @State private var rules = GlobalRulesConfig.load().rules
    @State private var editing: RuleDraft?

    private struct RuleDraft: Identifiable {
        let id = UUID()
        let index: Int?
        let raw: String
    }

    var body: some View {
        ClashMacSettingsFormContainer {
            Section {
                Toggle("Enable Global Rules", isOn: $isEnabled)
                    .accessibilityIdentifier("global-rules.enabled")
                    .onChange(of: isEnabled) { _ in persist() }
            } header: {
                Text("Global Rules")
            } footer: {
                Text("These rules are checked before the rules of every configuration, including subscriptions that bring their own. They live outside the profile, so a source update cannot drop them.")
            }

            Section {
                if rules.isEmpty {
                    Text(clash: .copy("No Global Rules"))
                        .foregroundStyle(.secondary)
                }
                ForEach(rules.indices, id: \.self) { index in
                    Button {
                        editing = RuleDraft(index: index, raw: rules[index])
                    } label: {
                        ConfigurationRuleRow(rules[index], showsChevron: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("global-rules.row.\(index)")
                }
                .onDelete { offsets in
                    rules.remove(atOffsets: offsets)
                    persist()
                }
                ClashAddRow(Text(clash: .copy("Add Rule"))) {
                    editing = RuleDraft(index: nil, raw: "")
                }
                .accessibilityIdentifier("global-rules.add")
            } header: {
                Text("Rules")
            } footer: {
                Text("One rule per line, for example DOMAIN-SUFFIX,example.com,DIRECT. A rule that names a policy a configuration does not define is left out for that configuration.")
            }
        }
        .clashPageTitle("Global Rules")
        .sheet(item: $editing) { draft in
            RuleEditorSheet(rule: draft.raw) { text in
                commit(text, at: draft.index)
            }
        }
    }

    private func commit(_ text: String, at index: Int?) {
        let rule = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rule.isEmpty else { return }
        if let index {
            rules[index] = rule
        } else {
            rules.insert(rule, at: 0)
        }
        persist()
    }

    private func persist() {
        var config = GlobalRulesConfig.load()
        config.isEnabled = isEnabled
        config.rules = rules
        GlobalRulesConfig.save(config)
        rules = GlobalRulesConfig.normalized(rules)
        restageRuntime()
    }
}

private struct RuleEditorSheet: View {
    let rule: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(rule: String, onSave: @escaping (String) -> Void) {
        self.rule = rule
        self.onSave = onSave
        _text = State(initialValue: rule)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(clash: .copy(rule.isEmpty ? "Add Rule" : "Edit Rule"))
                .font(.headline)
            TextField("DOMAIN-SUFFIX,example.com,DIRECT", text: $text)
                .font(.body.monospaced())
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("global-rules.field")
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text(clash: .copy("Cancel"))
                }
                .keyboardShortcut(.cancelAction)
                Button {
                    onSave(text)
                    dismiss()
                } label: {
                    Text(clash: .copy("Save"))
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}
