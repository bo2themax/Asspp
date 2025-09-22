//
//  AppStore.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import Combine
import Foundation

class AppStore: ObservableObject {
    var cancellables: Set<AnyCancellable> = .init()

    @MainActor
    @PublishedPersist(
        key: "Accounts",
        defaultValue: [],
        keychain: "wiki.qaq.Asspp.Accounts"
    )
    var accounts: [UserAccount]

    @MainActor
    @PublishedPersist(
        key: "DeviceIdentifier",
        defaultValue: "",
        keychain: "wiki.qaq.Asspp.DeviceIdentifier"
    )
    var deviceIdentifier: String

    @MainActor
    @PublishedPersist(key: "DemoMode", defaultValue: false)
    var demoMode: Bool

    @MainActor
    static let this = AppStore()

    @MainActor
    private init() {
        if deviceIdentifier.isEmpty {
            do {
                let systemIdentifier = try ApplePackage.DeviceIdentifier.system()
                deviceIdentifier = systemIdentifier
            } catch {
                logger.warning("failed to get system device identifier, falling back to random one: \(error)")
                let randomIdentifier = ApplePackage.DeviceIdentifier.random()
                deviceIdentifier = randomIdentifier
            }
        }
        logger.info("using device identifier: \(deviceIdentifier)")
        ApplePackage.Configuration.deviceIdentifier = deviceIdentifier
    }

    @MainActor
    @discardableResult
    func save(email: String, account: ApplePackage.Account) -> UserAccount {
        let account = UserAccount(account: account)
        accounts = (accounts.filter { $0.account.email != email } + [account])
            .sorted { $0.account.email < $1.account.email }
        return account
    }

    @MainActor
    func delete(id: UserAccount.ID) {
        accounts = accounts.filter { $0.id != id }
    }

    @MainActor
    var possibleRegions: Set<String> {
        Set(accounts.compactMap { ApplePackage.Configuration.countryCode(for: $0.account.store) })
    }

    @MainActor
    func eligibleAccounts(for region: String) -> [UserAccount] {
        accounts.filter { ApplePackage.Configuration.countryCode(for: $0.account.store) == region }
    }

    func withAccount<T>(id: String, _ body: (inout UserAccount) async throws -> T) async throws -> T {
        if let idx = await accounts.firstIndex(where: { $0.id == id }) {
            var account = await accounts[idx]
            let result = try await body(&account)
            let updatedAccount = account
            await MainActor.run { accounts[idx] = updatedAccount }
            return result
        } else {
            throw AuthenticationError.accountNotFound
        }
    }
}
