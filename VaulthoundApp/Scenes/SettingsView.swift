import SwiftUI

struct SettingsView: View {
    @AppStorage("scanDirectories") private var scanDirectories = "~/Developer,~/Projects,~/Code"
    @AppStorage("autoClipboardClear") private var autoClipboardClear = true
    @AppStorage("clipboardClearSeconds") private var clipboardClearSeconds = 30

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gear") }

            securitySettings
                .tabItem { Label("Security", systemImage: "lock.shield") }

            cliSettings
                .tabItem { Label("CLI", systemImage: "terminal") }
        }
        .frame(width: 450, height: 300)
    }

    @ViewBuilder
    private var generalSettings: some View {
        Form {
            Section("Project Scanning") {
                TextField("Scan Directories (comma-separated)", text: $scanDirectories)
                    .textFieldStyle(.roundedBorder)
                Text("Vaulthound will watch these directories for projects with .env files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var securitySettings: some View {
        Form {
            Section("Clipboard") {
                Toggle("Auto-clear clipboard after copying secrets", isOn: $autoClipboardClear)

                if autoClipboardClear {
                    Stepper("Clear after \(clipboardClearSeconds) seconds", value: $clipboardClearSeconds, in: 10...120, step: 10)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var cliSettings: some View {
        Form {
            Section("Command Line Tools") {
                HStack {
                    Text("Install `vaulthound` CLI to /usr/local/bin/")
                    Spacer()
                    Button("Install") {
                        installCLI()
                    }
                }

                Text("Or install via Homebrew: `brew install vaulthound`")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shell Hook") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add this line to your .zshrc to auto-load environments:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text(#"eval "$(vaulthound hook zsh)""#)
                            .font(.body.monospaced())
                            .textSelection(.enabled)

                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(#"eval "$(vaulthound hook zsh)""#, forType: .string)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func installCLI() {
        guard let bundlePath = Bundle.main.path(forAuxiliaryExecutable: "vaulthound") else { return }
        let dest = "/usr/local/bin/vaulthound"

        let script = "cp '\(bundlePath)' '\(dest)' && chmod +x '\(dest)'"
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", "do shell script \"\(script)\" with administrator privileges"]
        try? process.run()
    }
}
