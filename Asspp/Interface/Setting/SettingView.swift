//
//  SettingView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

struct SettingView: View {
    @StateObject var vm = AppStore.this

    var body: some View {
        #if os(iOS)
            NavigationView {
                formContent
            }
            .navigationViewStyle(.stack)
        #else
            NavigationStack {
                formContent
            }
        #endif
    }

    private var formContent: some View {
        FormOnTahoeList {
            Section {
                Toggle("Demo Mode", isOn: $vm.demoMode)
            } header: {
                Text("Demo Mode")
            } footer: {
                Text("By enabling this, all your accounts and sensitive information will be redacted.")
            }
            Section {
                Button("Delete All Downloads", role: .destructive) {
                    Downloads.this.removeAll()
                }
            } header: {
                Text("Downloads")
            } footer: {
                Text("Manage downloads.")
            }
            Section {
                Text(ProcessInfo.processInfo.hostName)
                    .redacted(reason: .placeholder, isEnabled: vm.demoMode)
                Text(ApplePackage.Configuration.deviceIdentifier)
                    .font(.system(.body, design: .monospaced))
                    .redacted(reason: .placeholder, isEnabled: vm.demoMode)
                #if canImport(UIKit)
                    Button("Open Settings") {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }
                #endif
                #if canImport(AppKit) && !canImport(UIKit)
                    Button("Open Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
                    }
                #endif
            } header: {
                Text("Host Name")
            } footer: {
                Text("Grant local network permission to install apps and communicate with system services. If hostname is empty, open Settings to grant permission.")
            }

            #if canImport(UIKit)
                Section {
                    Button("Install Certificate") {
                        UIApplication.shared.open(Installer.caURL)
                    }
                } header: {
                    Text("SSL")
                } footer: {
                    Text("On device installer requires your system to trust a self signed certificate. Tap the button to install it. After install, navigate to Settings > General > About > Certificate Trust Settings and enable full trust for the certificate.")
                }
            #endif

            #if canImport(AppKit) && !canImport(UIKit)
                Section {
                    Button("Show Certificate in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([Installer.ca])
                    }
                } header: {
                    Text("SSL")
                } footer: {
                    Text("On macOS, install certificates through System Keychain.")
                }
            #endif

            Section {
                Button("@Lakr233") {
                    #if canImport(UIKit)
                        UIApplication.shared.open(URL(string: "https://twitter.com/Lakr233")!)
                    #endif
                    #if canImport(AppKit) && !canImport(UIKit)
                        NSWorkspace.shared.open(URL(string: "https://twitter.com/Lakr233")!)
                    #endif
                }
                Button("Buy me a coffee! ☕️") {
                    #if canImport(UIKit)
                        UIApplication.shared.open(URL(string: "https://github.com/sponsors/Lakr233/")!)
                    #endif
                    #if canImport(AppKit) && !canImport(UIKit)
                        NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/Lakr233/")!)
                    #endif
                }
                Button("Feedback & Contact") {
                    #if canImport(UIKit)
                        UIApplication.shared.open(URL(string: "https://github.com/Lakr233/Asspp")!)
                    #endif
                    #if canImport(AppKit) && !canImport(UIKit)
                        NSWorkspace.shared.open(URL(string: "https://github.com/Lakr233/Asspp")!)
                    #endif
                }
            } header: {
                Text("About")
            } footer: {
                Text("Hope this app helps you!")
            }
            Section {
                Button("Reset", role: .destructive) {
                    try? FileManager.default.removeItem(at: documentsDirectory)
                    try? FileManager.default.removeItem(at: temporaryDirectory)
                    #if canImport(UIKit)
                        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                    #endif
                    #if canImport(AppKit) && !canImport(UIKit)
                        NSApp.terminate(nil)
                    #endif
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        exit(0)
                    }
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("This will reset all your settings.")
            }
        }
        .navigationTitle("Settings")
    }
}
