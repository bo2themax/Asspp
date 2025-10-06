//
//  AddDownloadView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/13.
//

import ApplePackage
import SwiftUI

struct AddDownloadView: View {
    @State var bundleID: String = ""
    @State var searchType: EntityType = .iPhone
    @State var selection: AppStore.UserAccount.ID = .init()
    @State var obtainDownloadURL = false
    @State var hint = ""

    @FocusState var searchKeyFocused

    @StateObject var avm = AppStore.this
    @StateObject var dvm = Downloads.this

    @Environment(\.dismiss) var dismiss

    var account: AppStore.UserAccount? {
        avm.accounts.first { $0.id == selection }
    }

    var body: some View {
        FormOnTahoeList {
            Section {
                TextField("Bundle ID", text: $bundleID)
                #if os(iOS)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.none)
                #endif
                    .focused($searchKeyFocused)
                    .onSubmit { startDownload() }
                Picker("EntityType", selection: $searchType) {
                    ForEach(EntityType.allCases, id: \.self) { type in
                        Text(type.rawValue)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Bundle ID")
            } footer: {
                Text("Tell us the bundle ID of the app to initiate a direct download. Useful to download apps that are no longer available in App Store.")
            }

            Section {
                Picker("Account", selection: $selection) {
                    ForEach(avm.accounts) { account in
                        Text(account.account.email)
                            .id(account.id)
                    }
                }
                .pickerStyle(.menu)
                .onAppear { selection = avm.accounts.first?.id ?? .init() }
                .redacted(reason: .placeholder, isEnabled: avm.demoMode)
            } header: {
                Text("Account")
            } footer: {
                Text("Select an account to download this app")
            }

            Section {
                Button(obtainDownloadURL ? "Communicating with Apple..." : "Request Download") {
                    startDownload()
                }
                .disabled(bundleID.isEmpty)
                .disabled(obtainDownloadURL)
                .disabled(account == nil)
            } footer: {
                if hint.isEmpty {
                    Text("The package can be installed later from the Downloads page.")
                } else {
                    Text(hint)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Direct Download")
    }

    func startDownload() {
        guard let account else { return }
        searchKeyFocused = false
        obtainDownloadURL = true
        Task {
            do {
                let software = try await ApplePackage.Lookup.lookup(bundleID: bundleID, countryCode: account.account.store)
                let appPackage = AppStore.AppPackage(software: software)
                try await dvm.startDownload(for: appPackage, accountID: account.id)
                await MainActor.run {
                    obtainDownloadURL = false
                    hint = "Download Requested"
                }
            } catch {
                await MainActor.run {
                    obtainDownloadURL = false
                    hint = "Unable to retrieve download url, please try again later." + "\n" + error.localizedDescription
                }
            }
        }
    }
}
