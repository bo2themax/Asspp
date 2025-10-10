//
//  ProductVersionView.swift
//  Asspp
//
//  Created by luca on 15.09.2025.
//

import ApplePackage
import SwiftUI

struct ProductVersionView: View {
    let accountIdentifier: String
    let package: AppStore.AppPackage

    @StateObject var dvm = Downloads.this
    @State var obtainDownloadURL: Bool = false
    @State var hint: Hint?

    var body: some View {
        if let req = dvm.downloadRequest(forArchive: package) {
            NavigationLink(destination: PackageView(pkg: req)) {
                HStack {
                    Text(package.software.version)
                    Spacer()
                    Text("Show Download")
                }
            }
        } else {
            Button {
                startDownload()
            } label: {
                VStack(alignment: .leading) {
                    if obtainDownloadURL {
                        Text("Communicating with Apple...")
                    } else {
                        HStack {
                            Text(package.software.version)
                            Spacer()
                            Text("Request Download")
                        }
                    }

                    if let hint {
                        Text(hint.message)
                            .foregroundColor(hint.color)
                    }
                }
            }
            .disabled(obtainDownloadURL)
        }
    }

    func startDownload() {
        obtainDownloadURL = true
        Task {
            do {
                try await dvm.startDownload(for: package, accountID: accountIdentifier)

                await MainActor.run {
                    obtainDownloadURL = false
                    hint = Hint(message: String(localized: "Download Requested"), color: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    obtainDownloadURL = false
                    hint = Hint(message: String(localized: "Unable to retrieve download url, please try again later.") + "\n" + error.localizedDescription, color: .red)
                }
            }
        }
    }
}
