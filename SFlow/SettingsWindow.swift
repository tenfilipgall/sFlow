import SwiftUI
import AppKit

extension Notification.Name {
    static let sflowForceReSeed = Notification.Name("com.sflow.forceReSeed")
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private init() {
        let hosting = NSHostingView(rootView: SettingsView())
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 340)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SFlow Settings"
        window.contentView = hosting
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            PrivacyTab()
                .tabItem { Label("Privacy", systemImage: "eye.slash") }
            AdvancedTab()
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 480, height: 300)
        .padding([.horizontal, .bottom])
    }
}

private struct GeneralTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General preferences will appear here.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

private struct PrivacyTab: View {
    @AppStorage("logMisses") private var logMisses: Bool = true
    @AppStorage("telemetry") private var telemetry: Bool = false

    var body: some View {
        Form {
            Toggle("Log miss events", isOn: $logMisses)
                .help("Records unrecognised clicks for sflow-analyze. Stored locally only.")
            Toggle("Share aggregated data with backend", isOn: $telemetry)
                .help("Not implemented yet — no data is sent.")
            Divider()
            HStack(spacing: 12) {
                Button("Open events.jsonl in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([EventLogger.defaultLogURL])
                }
                Button("Clear local data") {
                    try? FileManager.default.removeItem(at: EventLogger.defaultLogURL)
                }
            }
        }
        .padding()
    }
}

private struct AdvancedTab: View {
    @AppStorage("showExperimental") private var showExperimental: Bool = false
    @AppStorage("showDeveloperFeatures") private var showDeveloperFeatures: Bool = false
    @ObservedObject private var store: FalsePositiveStore = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Toggle("Show experimental shortcuts", isOn: $showExperimental)
                    .help("Activates low-confidence auto-discovered rules. May show incorrect shortcuts.")
                Toggle("Show developer features", isOn: $showDeveloperFeatures)
                    .help("Reveals an Apps tab with discovery diagnostics. For beta testing and debugging only.")
            }
            .padding([.horizontal, .top])

            Divider().padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("Recent shortcuts")
                    .font(.headline)
                    .padding([.horizontal, .top])

                if store.recentToasts.isEmpty {
                    Text("No shortcuts shown yet.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .padding(.horizontal)
                } else {
                    List(store.recentToasts) { record in
                        HStack(spacing: 8) {
                            Text(record.keys.map { keySymbol($0) }.joined())
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 60, alignment: .leading)
                            Text(record.hint)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Spacer()
                            if record.isDisabled {
                                Text("Disabled")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            } else {
                                Button("Report incorrect") {
                                    store.report(record: record)
                                }
                                .font(.caption)
                            }
                        }
                    }
                    .frame(height: 140)
                }
            }

            Divider().padding(.top, 4)

            Form {
                Button("Update built-in rules") {
                    NotificationCenter.default.post(name: .sflowForceReSeed, object: nil)
                }
                .help("Downloads the latest built-in shortcuts from the server.")
            }
            .padding([.horizontal, .bottom])
        }
    }
}
