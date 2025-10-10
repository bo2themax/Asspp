//
//  MainView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        #if os(macOS)
            MacSidebarMainView()
        #else
            LegacyTabMainView()
        #endif
    }
}

#if os(macOS)
    private struct MacSidebarMainView: View {
        @State private var selection: SidebarSection? = .home
        @StateObject private var downloads = Downloads.this

        var body: some View {
            NavigationSplitView {
                List(SidebarSection.allCases, selection: $selection) { section in
                    SidebarRow(section: section, downloads: downloads.runningTaskCount)
                        .tag(section)
                }
                .frame(minWidth: 220)
                .listStyle(.sidebar)
            } detail: {
                Group {
                    if let selection {
                        detailView(for: selection)
                    } else {
                        detailView(for: .home)
                    }
                }
                .frame(minWidth: 400, minHeight: 250)
            }
        }

        @ViewBuilder
        private func detailView(for section: SidebarSection) -> some View {
            switch section {
            case .home:
                WelcomeView()
            case .accounts:
                AccountView()
            case .search:
                SearchView()
            case .downloads:
                DownloadView()
            case .settings:
                SettingView()
            }
        }
    }

    private enum SidebarSection: Hashable, CaseIterable, Identifiable {
        case home
        case accounts
        case search
        case downloads
        case settings

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .home:
                "Home"
            case .accounts:
                "Accounts"
            case .search:
                "Search"
            case .downloads:
                "Downloads"
            case .settings:
                "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .home:
                "house"
            case .accounts:
                "person"
            case .search:
                "magnifyingglass"
            case .downloads:
                "arrow.down.circle"
            case .settings:
                "gear"
            }
        }
    }

    private struct SidebarRow: View {
        let section: SidebarSection
        let downloads: Int

        var body: some View {
            HStack {
                Label(section.title, systemImage: section.systemImage)
                if section == .downloads, downloads > 0 {
                    Spacer()
                    Text("\(downloads)")
                        .font(.caption2.bold())
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
#else
    private struct LegacyTabMainView: View {
        @StateObject var dvm = Downloads.this

        var body: some View {
            TabView {
                WelcomeView()
                    .tabItem { Label("Home", systemImage: "house") }
                AccountView()
                    .tabItem { Label("Accounts", systemImage: "person") }
                SearchView()
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                DownloadView()
                    .tabItem {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }
                    .badge(dvm.runningTaskCount) // putting badge inside will not work on iOS versions before 18
                SettingView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
        }
    }

    @available(iOS 18.0, *)
    struct NewMainView: View {
        @StateObject var dvm = Downloads.this

        var body: some View {
            TabView {
                Tab("Home", systemImage: "house") { WelcomeView() }
                Tab("Accounts", systemImage: "person") { AccountView() }
                Tab(role: .search) {
                    SearchView()
                }
                Tab("Downloads", systemImage: "arrow.down.circle") { DownloadView() }
                    .badge(dvm.runningTaskCount)
                Tab("Settings", systemImage: "gear") { SettingView() }
            }
            .neverMinimizeTab()
            .activateSearchWhenSearchTabSelected()
            .sidebarAdaptableTabView()
        }
    }
#endif
