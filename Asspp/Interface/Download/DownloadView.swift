//
//  DownloadView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import SwiftUI

struct DownloadView: View {
    @StateObject var vm = Downloads.this

    var body: some View {
        #if os(iOS)
            NavigationView {
                content
                    .navigationTitle("Downloads")
            }
            .navigationViewStyle(.stack)
        #else
            NavigationStack {
                content
                    .navigationTitle("Downloads")
            }
        #endif
    }

    var content: some View {
        FormOnTahoeList {
            if vm.manifests.isEmpty {
                Text("No downloads yet.")
            } else {
                packageList
            }
        }
        .toolbar {
            NavigationLink(destination: AddDownloadView()) {
                Image(systemName: "plus")
            }
        }
    }

    var packageList: some View {
        ForEach(vm.manifests, id: \.id) { req in
            NavigationLink(destination: PackageView(pkg: req)) {
                VStack(spacing: 8) {
                    ArchivePreviewView(archive: req.package)
                    SimpleProgress(progress: req.state.percent)
                        .animation(.interactiveSpring, value: req.state.percent)
                    HStack {
                        Text(req.hint)
                        Spacer()
                        Text(req.creation.formatted())
                    }
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                }
            }
            .contextMenu {
                let actions = vm.getAvailableActions(for: req)
                ForEach(actions, id: \.self) { action in
                    let label = vm.getActionLabel(for: action)
                    Button(role: label.isDestructive ? .destructive : .none) {
                        Task { vm.performDownloadAction(for: req, action: action) }
                    } label: {
                        Label(label.title, systemImage: label.systemImage)
                    }
                }
            }
        }
    }
}

extension PackageManifest {
    var hint: String {
        if let error = state.error {
            return error
        }
        return switch state.status {
        case .pending:
            String(localized: "Pending...")
        case .downloading:
            [
                String(Int(state.percent * 100)) + "%",
                state.speed.isEmpty ? "" : state.speed + "/s",
            ]
            .compactMap(\.self)
            .joined(separator: " ")
        case .paused:
            String(localized: "Paused")
        case .completed:
            String(localized: "Completed")
        case .failed:
            String(localized: "Failed")
        }
    }
}
