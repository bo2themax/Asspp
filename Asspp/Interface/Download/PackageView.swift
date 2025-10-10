//
//  PackageView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import Kingfisher
import SwiftUI

#if canImport(AppKit) && !canImport(UIKit)
    import AppKit
#endif

struct PackageView: View {
    @StateObject var pkg: PackageManifest

    var archive: AppStore.AppPackage {
        pkg.package
    }

    var url: URL { pkg.targetLocation }

    @Environment(\.dismiss) var dismiss
    #if os(iOS)
        @State var installer: Installer?
        @State var error: String = ""
    #endif
    #if os(macOS)
        @State private var copied = false
    #endif

    @StateObject var vm = AppStore.this
    @ObservedObject var downloads = Downloads.this

    var body: some View {
        FormOnTahoeList {
            Section {
                ArchivePreviewView(archive: archive)
            } header: {
                Text("Package")
            } footer: {
                Text("\(archive.software.bundleID) - \(archive.software.version)")
            }

            if pkg.completed {
                #if os(macOS)
                    DeviceCTLInstallSection(ipaFile: url, software: pkg.package.software)
                #endif
                #if os(iOS)
                    Section {
                        Button("Install") {
                            Task {
                                do {
                                    installer = try await Installer(archive: archive, path: url)
                                } catch {
                                    self.error = error.localizedDescription
                                }
                            }
                        }
                        .sheet(item: $installer) {
                            installer?.destroy()
                            installer = nil
                        } content: {
                            InstallerView(installer: $0)
                        }

                        Button("Install via AirDrop") {
                            let newUrl = temporaryDirectory
                                .appendingPathComponent("\(archive.software.bundleID)-\(archive.software.version)")
                                .appendingPathExtension("ipa")
                            try? FileManager.default.removeItem(at: newUrl)
                            try? FileManager.default.copyItem(at: url, to: newUrl)
                            AirDrop(items: [newUrl])
                        }
                    } header: {
                        Text("Control")
                    } footer: {
                        if error.isEmpty {
                            Text("Direct install may have limitations that cannot be bypassed. Use AirDrop if possible on another device.")
                        } else {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                #endif

                Section {
                    NavigationLink("Content Viewer") {
                        FileListView(packageURL: pkg.targetLocation)
                    }
                    #if os(macOS)
                        HStack {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            } label: {
                                Text(url.path)
                                    .multilineTextAlignment(.leading)
                            }
                            .help("Show in Finder")
                            .buttonStyle(.borderless)
                            .tint(.accentColor)
                            Spacer()
                            Button {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(url.path, forType: .string)
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    copied = false
                                }
                            } label: {
                                Image(systemName: copied ? "checkmark" : "document.on.document")
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .help("Copy File Path")
                            .buttonStyle(.borderless)
                            .tint(.accentColor)
                        }
                    #endif
                } header: {
                    Text("Analysis")
                } footer: {
                    Text("Developer options.")
                }
            } else {
                Section {
                    let actions = downloads.getAvailableActions(for: pkg)
                    ForEach(actions.filter { $0 != .delete }, id: \.self) { action in
                        let label = downloads.getActionLabel(for: action)
                        Button(label.title) {
                            downloads.performDownloadAction(for: pkg, action: action)
                        }
                        .foregroundStyle(label.isDestructive ? .red : .primary)
                    }
                } header: {
                    Text("Incomplete Package")
                } footer: {
                    switch pkg.state.status {
                    case .pending:
                        Text("\(Int(pkg.state.percent * 100))%...")
                    case .downloading:
                        Text("\(Int(pkg.state.percent * 100))%...")
                    case .paused:
                        Text("Paused at \(Int(pkg.state.percent * 100))%")
                    case .completed:
                        Group {}
                    case .failed:
                        Text("Download failed.")
                    }
                }
            }

            Section {
                Text(pkg.account.account.email)
                    .redacted(reason: .placeholder, isEnabled: vm.demoMode)
                Text("\(pkg.account.account.store) - \(ApplePackage.Configuration.countryCode(for: pkg.account.account.store) ?? "-1")")
            } header: {
                Text("Account")
            } footer: {
                Text("This account is used to download this package. If you choose to AirDrop, your target device must sign in or previously signed in to this account and have at least one app installed.")
            }

            Section {
                let deleteAction = DownloadAction.delete
                let label = downloads.getActionLabel(for: deleteAction)
                Button(label.title) {
                    Task { downloads.performDownloadAction(for: pkg, action: deleteAction) }
                    dismiss()
                }
                .foregroundStyle(label.isDestructive ? .red : .primary)
            } header: {
                Text("Danger Zone")
            } footer: {
                Text(url.path)
            }
        }
        .navigationTitle(pkg.package.software.name)
    }
}
