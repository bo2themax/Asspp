//
//  FileListView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/19.
//

import SwiftUI
import ZIPFoundation

struct FileListView: View {
    let packageURL: URL
    let prefix: URL

    init(packageURL: URL, prefix: URL = .init(fileURLWithPath: "/")) {
        self.packageURL = packageURL
        self.prefix = prefix
    }

    @State var items: [Entry] = []
    @State var message = ""
    @State var searchText = ""

    var interfaceItems: [Entry] {
        let inputWithPrefix = items
            .filter { input in
                var inputPath = input.path
                if !inputPath.hasPrefix("/") { inputPath = "/" + inputPath }
                let inputURL = URL(fileURLWithPath: inputPath)

                return inputURL.deletingLastPathComponent().path == prefix.path
            }
        return if searchText.isEmpty {
            inputWithPrefix
        } else {
            inputWithPrefix.filter {
                $0.path
                    .components(separatedBy: "/")
                    .last?
                    .lowercased()
                    .contains(searchText.lowercased())
                    ?? false
            }
        }
    }

    var body: some View {
        FormOnTahoeList {
            Section {
                ForEach(interfaceItems, id: \.path) { item in
                    switch item.type {
                    case .directory:
                        NavigationLink(URL(fileURLWithPath: item.path).lastPathComponent) {
                            FileListView(packageURL: packageURL, prefix: URL(fileURLWithPath: item.path))
                        }
                    case .file:
                        NavigationLink(URL(fileURLWithPath: item.path).lastPathComponent) {
                            FileAnalysisView(packageURL: packageURL, relativePath: item.path)
                        }
                    case .symlink:
                        Label(item.path, systemImage: "link")
                    }
                }
                .font(.system(.footnote, design: .monospaced))
            } header: {
                Text(String(format: "Content - %@", prefix.path))
            } footer: {
                if message.isEmpty {
                    Text(String(format: "%d items", items.count))
                } else {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
        }
        #if os(iOS)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        #else
        .searchable(text: $searchText)
        #endif
        .animation(.spring, value: items)
        .onAppear {
            Task {
                await MainActor.run {
                    message = "Examining contents..."
                }
                do { try await loadContents() }
                catch {
                    await MainActor.run { message = error.localizedDescription }
                }
            }
        }
        .navigationTitle("Contents")
    }

    func loadContents() async throws {
        let archive = try Archive(url: packageURL, accessMode: .read)
        // list all files
        var buildList = [Entry]()
        let files = archive.makeIterator()
        while let file = files.next() {
            buildList.append(file)
        }
        await MainActor.run {
            items = buildList
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        await MainActor.run {
            message = ""
        }
    }
}
