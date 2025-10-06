//
//  FileAnalysisView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/19.
//

import SwiftUI
import ZIPFoundation

#if canImport(UIKit)
    import UIKit

    typealias PlatformImage = UIImage
#elseif canImport(AppKit) && !canImport(UIKit)
    import AppKit

    typealias PlatformImage = NSImage
#else
    typealias PlatformImage = AnyObject
#endif

struct FileAnalysisView: View {
    let packageURL: URL
    let relativePath: String

    let tempDir = temporaryDirectory
        .appendingPathComponent(UUID().uuidString)

    @State var message = ""
    @State var extractedFile: URL?
    @State var thumbnail: PlatformImage?

    var renderedThumbnail: Image? {
        guard let thumbnail else { return nil }
        #if canImport(UIKit)
            return Image(uiImage: thumbnail)
        #elseif canImport(AppKit) && !canImport(UIKit)
            return Image(nsImage: thumbnail)
        #else
            return nil
        #endif
    }

    var body: some View {
        FormOnTahoeList {
            if let extractedFile {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        if let image = renderedThumbnail {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Image(systemName: "doc.text.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text(extractedFile.lastPathComponent)
                            .font(.system(.headline))
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Preview")
                } footer: {
                    Text(extractedFile.path)
                }
                .transition(.opacity)
                Section {
                    Button("Share File") {
                        AirDrop(items: [extractedFile])
                    }
                } header: {
                    Text("Operations")
                } footer: {
                    Text(message)
                        .foregroundStyle(.red)
                }
                .transition(.opacity)
            } else {
                Text(message.isEmpty ? "Not Available" : message)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.spring, value: relativePath)
        .animation(.spring, value: extractedFile)
        .onAppear {
            message = "Examining contents..."
            Task {
                do { try await loadContents() }
                catch {
                    await MainActor.run { message = error.localizedDescription }
                }
            }
        }
        .onDisappear {
            try? FileManager.default.removeItem(at: tempDir)
        }
        .navigationTitle("Contents")
    }

    func loadContents() async throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let archive = try Archive(url: packageURL, accessMode: .read)
        guard let file = archive[relativePath] else {
            assertionFailure()
            throw NSError(domain: "FileAnalysisView", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "File not found",
            ])
        }
        let destination = tempDir.appendingPathComponent(relativePath)
        _ = try archive.extract(file, to: destination)
        await MainActor.run {
            message = "Extracted File"
            extractedFile = destination
        }
    }
}
