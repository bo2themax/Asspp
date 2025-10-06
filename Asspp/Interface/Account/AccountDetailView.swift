//
//  AccountDetailView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit) && !canImport(UIKit)
    import AppKit
#endif

struct AccountDetailView: View {
    let accountId: AppStore.UserAccount.ID

    @StateObject var vm = AppStore.this
    @Environment(\.dismiss) var dismiss

    private var account: AppStore.UserAccount? {
        vm.accounts.first { $0.id == accountId }
    }

    @State var rotating = false
    @State var rotatingHint = ""

    var body: some View {
        FormOnTahoeList {
            Section {
                Text(account?.account.email ?? "")
                    .onTapGesture { copyToClipboard(account?.account.email) }
                    .redacted(reason: .placeholder, isEnabled: vm.demoMode)
            } header: {
                Text("Apple ID")
            } footer: {
                Text("This email is used to sign in to Apple services.")
            }
            Section {
                Text("\(account?.account.store ?? "") - \(ApplePackage.Configuration.countryCode(for: account?.account.store ?? "") ?? "Unknown")")
                    .onTapGesture { copyToClipboard(account?.account.email) }
            } header: {
                Text("Country Code")
            } footer: {
                Text("App Store requires this country code to identify your package region.")
            }
            Section {
                Text(account?.account.directoryServicesIdentifier ?? "")
                    .font(.system(.body, design: .monospaced))
                    .onTapGesture { copyToClipboard(account?.account.email) }
                    .redacted(reason: .placeholder, isEnabled: vm.demoMode)
            } header: {
                Text("Directory Services ID")
            } footer: {
                Text("This ID, combined with a random seed generated on this device, can be used to download packages from the App Store.")
            }
            Section {
                SecureField(text: .constant(account?.account.passwordToken ?? "")) {
                    Text("Password Token")
                }
                if rotating {
                    Button("Rotating...") {}
                        .disabled(true)
                } else {
                    Button("Rotate Token") { rotate() }
                }
            } header: {
                Text("Password Token")
            } footer: {
                if rotatingHint.isEmpty {
                    Text("If you fail to acquire a license for a product, rotating the password token may help. This will use the initial password to authenticate with the App Store again.")
                } else {
                    Text(rotatingHint)
                        .foregroundStyle(.red)
                }
            }
            Section {
                Button("Delete") {
                    vm.delete(id: account?.id ?? "")
                    dismiss()
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Account Details")
    }

    func rotate() {
        rotating = true
        Task {
            do {
                try await vm.rotate(id: account?.id ?? "")
                DispatchQueue.main.async {
                    rotating = false
                    rotatingHint = String(localized: "Success")
                }
            } catch {
                DispatchQueue.main.async {
                    rotating = false
                    rotatingHint = error.localizedDescription
                }
            }
        }
    }

    func copyToClipboard(_ text: String?) {
        guard let text, !text.isEmpty else { return }
        #if canImport(UIKit)
            UIPasteboard.general.string = text
        #elseif canImport(AppKit) && !canImport(UIKit)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        #endif
    }
}
