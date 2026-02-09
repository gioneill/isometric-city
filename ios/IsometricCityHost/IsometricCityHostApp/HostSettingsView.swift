import SwiftUI

struct HostSettingsView: View {
    @Binding var isPresented: Bool

    @AppStorage("isocity.host.devURL") private var devURLString: String = "http://127.0.0.1:3000"
    @AppStorage("isocity.host.useDevServer") private var useDevServer: Bool = true
    @AppStorage("isocity.host.toolbarMode") private var toolbarMode: String = "category"
    @AppStorage("isocity.host.hudDensity") private var hudDensity: String = "compact"

    var body: some View {
        NavigationStack {
            Form {
                Section("Runtime") {
                    Toggle("Use Dev Server", isOn: $useDevServer)
                    TextField("Dev URL", text: $devURLString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Section("Native HUD") {
                    Picker("Toolbar Mode", selection: $toolbarMode) {
                        Text("Category First").tag("category")
                        Text("Quick Tools").tag("quick")
                    }
                    Picker("HUD Density", selection: $hudDensity) {
                        Text("Minimal").tag("minimal")
                        Text("Compact").tag("compact")
                        Text("Full").tag("full")
                    }
                }

                Section("A/B Variant") {
                    Text("This branch uses web-owned gestures (Option B).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("URL query includes host=ios&gesture=web so the web app keeps pan/pinch/tap behavior.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Host Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
