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
    @StateObject var vm = AppStore.this
    @State var addAccount = false

    var body: some View {
        #if os(macOS)
            NavigationStack {
                content
                    .navigationTitle("Accounts")
                    .toolbar { addToolbar }
            }
            .sheet(isPresented: $addAccount) {
                AddAccountView()
            }
        #else
            NavigationView {
                content
                    .background(
                        NavigationLink(
                            destination: AddAccountView(),
                            isActive: $addAccount,
                            label: { EmptyView() }
                        )
                    )
                    .navigationTitle("Accounts")
                    .toolbar { addToolbar }
            }
            .navigationViewStyle(.stack)
        #endif
    }

    var content: some View {
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
    }

    @ToolbarContentBuilder
    var addToolbar: some ToolbarContent {
        ToolbarItem {
            Button {
                addAccount.toggle()
            } label: {
                Label("Add Account", systemImage: "plus")
            }
        }
    }
}
