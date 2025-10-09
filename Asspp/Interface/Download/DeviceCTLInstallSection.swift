//
//  DeviceCTLInstallSection.swift
//  Asspp
//
//  Created by luca on 09.10.2025.
//

#if os(macOS)
    import ApplePackage
    import SwiftUI

    struct DeviceCTLInstallSection: View {
        @State var dm = DeviceManager.this
        @State var installed: DeviceCTL.App?
        @State var isLoading = false
        @State var wiggle: Bool = false
        @State var installSuccess = false
        let ipaFile: URL
        let software: Software
        var body: some View {
            if !dm.devices.isEmpty {
                section
            }
        }

        var section: some View {
            Section {
                installerContent
            } header: {
                HStack {
                    Label("Control", systemImage: installSuccess ? "checkmark" : dm.selectedDevice?.type.symbol ?? "")
                        .contentTransition(.symbolEffect(.replace))
                    Spacer()

                    if dm.installingProcess != nil || isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    }
                    if !dm.devices.isEmpty {
                        Button {
                            wiggle.toggle()
                            reloadDevice()
                        } label: {
                            Label("Refresh Devices", systemImage: "arrow.clockwise")
                                .symbolEffect(.wiggle, options: .nonRepeating, value: wiggle)
                        }
                        .buttonStyle(.borderless)
                        .disabled(isLoading || dm.installingProcess != nil)
                    }
                }
            } footer: {
                VStack {
                    if let installed {
                        Text("Existing Version: \(installed.version) (\(installed.bundleVersion))")
                    }

                    if let hint = dm.hint {
                        Text(hint.message)
                            .foregroundColor(hint.color)
                    }
                }
            }
        }

        var installerContent: some View {
            Picker(selection: $dm.selectedDeviceID) {
                ForEach(dm.devices) { d in
                    Button {} label: { // little hack to show rich menu
                        Text(d.name)
                        Text(String(localized: "\(d.model)\n\(d.type.osVersionPrefix) \(d.osVersionNumber)(\(d.osBuildUpdate))"))
                    }
                    .tag(d.id)
                }
            } label: {
                HStack {
                    Button(dm.installingProcess != nil ? "Cancel" : "Install") {
                        installOrStop()
                    }
                    .disabled(dm.selectedDevice == nil || isLoading || dm.hint?.isRed == true)
                }
            }
            .task(id: dm.selectedDevice?.id) {
                await fetchInstalledApp()
            }
        }

        func installOrStop() {
            if let process = dm.installingProcess {
                process.terminate()
                return
            }
            guard let device = dm.selectedDevice else { return }
            Task {
                installSuccess = await dm.install(ipa: ipaFile, to: device)
                await fetchInstalledApp()
                try? await Task.sleep(for: .seconds(1))
                installSuccess = false // hide symbol
            }
        }

        func fetchInstalledApp() async {
            guard let device = dm.selectedDevice else {
                return
            }
            installed = nil
            isLoading = true
            installed = await dm.loadApps(for: device, bundleID: software.bundleID).first
            isLoading = false
        }

        func reloadDevice() {
            Task {
                isLoading = true
                installed = nil
                await dm.loadDevices()
                await fetchInstalledApp()
            }
        }
    }
#endif
