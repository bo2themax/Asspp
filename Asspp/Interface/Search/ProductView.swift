//
//  ProductView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import Kingfisher
import SwiftUI

struct ProductView: View {
    @StateObject var archive: AppPackageArchive

    var region: String {
        archive.region
    }

    init(archive: AppStore.AppPackage, region: String) {
        _archive = .init(wrappedValue: AppPackageArchive(accountID: nil, region: region, package: archive))
    }

    @StateObject var vm = AppStore.this
    @StateObject var dvm = Downloads.this

    var eligibleAccounts: [AppStore.UserAccount] {
        vm.eligibleAccounts(for: region)
    }

    var account: AppStore.UserAccount? {
        vm.accounts.first { $0.id == selection }
    }

    @State var selection: AppStore.UserAccount.ID = .init()
    @State var obtainDownloadURL = false
    @State var showDownloadPage = false
    @State var licenseHint: String = ""
    @State var acquiringLicense = false
    @State var showLicenseAlert = false
    @State var hint: String = ""
    @State var hintColor: Color?

    let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter
    }()

    var formattedSize: String? {
        guard let sizeBytes = archive.package.software.fileSizeBytes.flatMap(Int64.init(_:)) else {
            return nil
        }
        return sizeFormatter.string(fromByteCount: sizeBytes)
    }

    var body: some View {
        List {
            accountSelector
            buttons
            packageHeader
            packageDescription
            if account == nil {
                Section {
                    Text("No account available for this region.")
                        .foregroundStyle(.red)
                } header: {
                    Text("Error")
                } footer: {
                    Text("Please add an account in the Accounts page.")
                }
            }
            pricing
        }
        .onAppear {
            selection = eligibleAccounts.first?.id ?? .init()
        }
        .navigationTitle("Select Account")
        .alert("License Required", isPresented: $showLicenseAlert) {
            var confirmRole: ButtonRole?
            if #available(iOS 26.0, *) {
                confirmRole = .confirm
            }

            return Group {
                Button("Acquire License", role: confirmRole) {
                    acquireLicense()
                }

                Button("Cancel", role: .cancel) {}
            }
        } message: {}
    }

    var packageHeader: some View {
        Section {
            PackageDisplayView(archive: archive.package)
            NavigationLink {
                ProductHistoryView(vm: AppPackageArchive(accountID: selection, region: region, package: archive.package))
            } label: {
                HStack {
                    Text("Version \(archive.package.software.version)")
                    Spacer()
                    if let date = archive.releaseDate {
                        Text(date.formatted(.relative(presentation: .numeric)))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let formattedSize {
                HStack {
                    Text("Size")
                    Spacer()
                    Text(formattedSize)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Compatibility")
                Spacer()
                Text("\(archive.package.software.minimumOsVersion)+")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Package")
        }
    }

    var packageDescription: some View {
        Section {
            Text(archive.package.software.releaseNotes ?? "")
        } header: {
            Text("What's New")
        }
    }

    var pricing: some View {
        Section {
            Text("\(archive.formattedPrice)")
                .font(.system(.body, design: .rounded))
            if archive.price == 0 {
                Button("Acquire License") {
                    acquireLicense()
                }
                .disabled(acquiringLicense)
                .disabled(account == nil)
            }
        } header: {
            Text("Pricing")
        } footer: {
            if licenseHint.isEmpty {
                Text("Acquiring a license is not available for paid apps. Purchase from the App Store first, then download here. If you've already purchased it, this may fail.")
            } else {
                Text(licenseHint)
                    .foregroundStyle(.red)
            }
        }
    }

    var accountSelector: some View {
        Section {
            Picker("Account", selection: $selection) {
                ForEach(eligibleAccounts) { account in
                    Text(account.account.email)
                        .id(account.id)
                }
            }
            .pickerStyle(.menu)
            .redacted(reason: .placeholder, isEnabled: vm.demoMode)
        } header: {
            Text("Account")
        } footer: {
            Text("You have searched this package with region \(region)")
        }
    }

    var buttons: some View {
        Section {
            if let req = dvm.downloadRequest(forArchive: archive.package) {
                NavigationLink(destination: PackageView(pkg: req), isActive: $showDownloadPage) {
                    Text("Show Download")
                }
            } else {
                Button(obtainDownloadURL ? "Communicating with Apple..." : "Request Download") {
                    startDownload()
                }
                .disabled(obtainDownloadURL)
                .disabled(account == nil)
            }
        } header: {
            Text("Download")
        } footer: {
            if hint.isEmpty {
                Text("Package can be installed later in download page.")
            } else {
                Text(hint)
                    .foregroundColor(hintColor)
            }
        }
    }

    func startDownload() {
        guard let account else { return }
        obtainDownloadURL = true
        Task {
            do {
                try await dvm.startDownload(for: archive.package, accountID: account.id)
                await MainActor.run {
                    obtainDownloadURL = false
                    hint = String(localized: "Download Requested")
                    hintColor = nil
                    showDownloadPage = true
                }
            } catch ApplePackageError.licenseRequired where archive.package.software.price == 0 && !acquiringLicense {
                DispatchQueue.main.async {
                    obtainDownloadURL = false
                    showLicenseAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    obtainDownloadURL = false
                    hint = String(localized: "Unable to retrieve download url, please try again later.") + "\n" + error.localizedDescription
                    hintColor = .red
                }
            }
        }
    }

    func acquireLicense() {
        guard let account else { return }
        acquiringLicense = true
        Task {
            do {
                try await vm.withAccount(id: account.id) { userAccount in
                    try await ApplePackage.Authenticator.rotatePasswordToken(for: &userAccount.account)
                    try await ApplePackage.Purchase.purchase(
                        account: &userAccount.account,
                        app: archive.package.software
                    )
                }
                DispatchQueue.main.async {
                    acquiringLicense = false
                    licenseHint = String(localized: "Request Successes")
                }
            } catch {
                DispatchQueue.main.async {
                    acquiringLicense = false
                    licenseHint = error.localizedDescription
                }
            }
        }
    }
}

extension AppStore.AppPackage {
    var displaySupportedDevicesIcon: String {
        // TODO: assuming iPhone for now
        "iphone"
    }
}
