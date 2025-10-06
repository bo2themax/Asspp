//
//  ProductHistoryView.swift
//  Asspp
//
//  Created by luca on 15.09.2025.
//

import ApplePackage
import SwiftUI

struct ProductHistoryView: View {
    @StateObject var vm: AppPackageArchive
    @State var showErrorAlert = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        FormOnTahoeList {
            ForEach(vm.versionIdentifiers, id: \.self) { key in
                if let aid = vm.accountIdentifier, let pkg = vm.package(for: key) {
                    Menu {
                        Button("Download \(pkg.software.version)") {
                            Task {
                                do {
                                    try await Downloads.this.startDownload(for: pkg, accountID: aid)
                                } catch {
                                    vm.error = error.localizedDescription
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(pkg.software.version)
                                .foregroundColor(.accentColor)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                } else {
                    Button {
                        vm.populateVersionItem(for: key)
                    } label: {
                        HStack {
                            Text(key).foregroundColor(.secondary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .overlay {
            ZStack {
                Rectangle()
                    .foregroundStyle(.clear)
                    .background(.ultraThinMaterial)
                ProgressView()
                    .progressViewStyle(.circular)
                #if os(macOS)
                    .controlSize(.small)
                #endif
            }
            .opacity(vm.loading ? 1 : 0)
            .animation(.default, value: vm.loading)
            .ignoresSafeArea(edges: [.vertical])
        }
        .animation(.default, value: vm.versionIdentifiers)
        .animation(.default, value: vm.versionItems)
        .animation(.default, value: vm.loading)
        .navigationTitle("Version History")
        .toolbar {
            ToolbarItem(placement: toolbarPlacement) {
                Menu {
                    Button {
                        vm.populateNextVersionItems()
                    } label: {
                        Label("Load More", systemImage: "arrow.down.circle")
                    }
                    .disabled(vm.isVersionItemsFullyLoaded)
                    Divider()
                    Button(role: .destructive) {
                        vm.clearVersionItems()
                        vm.populateVersionIdentifiers {
                            await MainActor.run { vm.populateNextVersionItems() }
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(vm.loading) // just make sure
                .opacity(vm.loading ? 0 : 1)
                .overlay { // using overlay to maintain same size while loading
                    if vm.loading {
                        ProgressView()
                            .progressViewStyle(.circular)
                        #if os(macOS)
                            .controlSize(.small)
                        #endif
                    }
                }
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Oops"),
                message: Text(vm.error ?? String(localized: "Unknown Error")),
                dismissButton: .default(Text("OK"), action: {
                    if vm.shouldDismiss {
                        dismiss()
                    }
                })
            )
        }
        .onAppear {
            guard vm.versionItems.isEmpty else { return }
            vm.populateVersionIdentifiers {
                await MainActor.run { vm.populateNextVersionItems() }
            }
        }
    }

    private var toolbarPlacement: ToolbarItemPlacement {
        #if os(iOS)
            .topBarTrailing
        #else
            .automatic
        #endif
    }
}
