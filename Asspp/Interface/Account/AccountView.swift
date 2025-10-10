//
//  AccountView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import Combine
import SwiftUI

struct AccountView: View {
    @StateObject private var vm = AppStore.this
    @State private var addAccount = false
    @State private var selectedID: AppStore.UserAccount.ID?

    var body: some View {
        #if os(macOS)
            macOSBody
        #else
            iOSBody
        #endif
    }

    #if os(macOS)
        private var macOSBody: some View {
            NavigationStack {
                accountsTable
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .navigationTitle("Accounts")
                    .toolbar { macToolbar }
            }
            .sheet(isPresented: $addAccount) {
                AddAccountView()
                    .frame(idealHeight: 200)
            }
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }

        private var accountsTable: some View {
            Table(vm.accounts, selection: $selectedID) {
                TableColumn("Email") { account in
                    NavigationLink(value: account.id) {
                        Text(account.account.email)
                            .redacted(reason: .placeholder, isEnabled: vm.demoMode)
                    }
                }

                TableColumn("Region") { account in
                    Text(account.account.store)
                }

                TableColumn("Storefront") { account in
                    Text(ApplePackage.Configuration.countryCode(for: account.account.store) ?? "-")
                }
            }
            .navigationDestination(for: AppStore.UserAccount.ID.self) { id in
                AccountDetailView(accountId: id)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if vm.accounts.isEmpty {
                    ContentUnavailableView(
                        label: {
                            Label("No Accounts", systemImage: "person.crop.circle.badge.questionmark")
                        },
                        description: {
                            Text("Add an Apple ID to start downloading IPA packages.")
                        },
                        actions: {
                            Button("Add Account") { addAccount.toggle() }
                        }
                    )
                    .padding()
                }
            }
        }

        private var footer: some View {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.title3)
                Text("Accounts are stored securely in your Keychain and can be removed at any time from the detail view.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        @ToolbarContentBuilder
        private var macToolbar: some ToolbarContent {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addAccount.toggle()
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
            }
        }
    #endif

    #if !os(macOS)
        private var iOSBody: some View {
            NavigationView {
                List {
                    Section {
                        ForEach(vm.accounts) { account in
                            NavigationLink(destination: AccountDetailView(accountId: account.id)) {
                                Text(account.account.email)
                                    .redacted(reason: .placeholder, isEnabled: vm.demoMode)
                            }
                        }
                        if vm.accounts.isEmpty {
                            Text("No accounts yet.")
                        }
                    } header: {
                        Text("Apple IDs")
                    } footer: {
                        Text("Your accounts are saved in your Keychain and will be synced across devices with the same iCloud account signed in.")
                    }
                }
                .navigationTitle("Accounts")
                .toolbar {
                    ToolbarItem {
                        Button {
                            addAccount.toggle()
                        } label: {
                            Label("Add Account", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $addAccount) { AddAccountView() }
        }
    #endif
}
