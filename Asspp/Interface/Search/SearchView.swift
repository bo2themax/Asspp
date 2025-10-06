//
//  SearchView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import Kingfisher
import SwiftUI

struct SearchView: View {
    @AppStorage("searchKey") var searchKey = ""
    @AppStorage("searchRegion") var searchRegion = "US"
    @FocusState var searchKeyFocused
    @State var searchType = EntityType.iPhone

    @State var searching = false
    let regionKeys = Array(ApplePackage.Configuration.storeFrontValues.keys.sorted())

    @State var searchInput: String = ""
    #if DEBUG
        @AppStorage("searchResults") // reduce API calls
        var searchResult: [AppStore.AppPackage] = []
    #else
        @State var searchResult: [AppStore.AppPackage] = []
    #endif

    @StateObject var vm = AppStore.this
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    var possibleRegion: Set<String> {
        vm.possibleRegions
    }

    var body: some View {
        #if os(iOS)
            if #available(iOS 16, *) {
                // Temporary workaround for the auto-pop issue on iOS 16 when using NavigationView
                // reference: https://stackoverflow.com/questions/66559814/swiftui-navigationlink-pops-out-by-itself#comment136786758_77588007
                NavigationStack {
                    if #available(iOS 26.0, *) {
                        modernContent
                    } else {
                        legacyContent
                    }
                }
            } else {
                NavigationView {
                    legacyContent
                }
            }
        #else
            NavigationStack {
                legacyContent
            }
        #endif
    }

    var searchTypePicker: some View {
        Picker(selection: $searchType) {
            ForEach(EntityType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        } label: {
            Label("Type", systemImage: searchType.iconName)
        }
        .onChangeCompat(of: searchType) { _ in
            searchResult = []
        }
    }

    var possibleRegionKeys: [String] {
        regionKeys.filter { possibleRegion.contains($0) }
    }

    @ViewBuilder
    func searchRegionView(isAllRegionsWrappedInMenu: Bool = true) -> some View {
        Group {
            if !possibleRegionKeys.isEmpty {
                buildPickView(
                    for: possibleRegionKeys
                ) {
                    Label("Available Regions", systemImage: "checkmark.seal")
                }
                if isAllRegionsWrappedInMenu {
                    Menu {
                        buildPickView(
                            for: regionKeys
                        ) {
                            EmptyView()
                        }
                    } label: {
                        Label("All Regions", systemImage: "globe")
                    }
                } else {
                    // Wrapping in Menu on macOS will cause an addition hover to show all the regions
                    buildPickView(
                        for: regionKeys
                    ) {
                        Label("All Regions", systemImage: "globe")
                    }
                }
            } else {
                // Reduce one interaction
                buildPickView(
                    for: regionKeys
                ) {
                    EmptyView()
                }
            }
        }
        .onChangeCompat(of: searchRegion) { _ in
            searchResult = []
        }
    }

    @ToolbarContentBuilder
    var tools: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Menu {
                searchTypePicker
                    .pickerStyle(.menu)
                Divider()
                #if os(iOS)
                    searchRegionView()
                #else
                    searchRegionView(isAllRegionsWrappedInMenu: false)
                #endif
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    var content: some View {
        FormOnTahoeList {
            if searching || !searchResult.isEmpty {
                Section(searching ? "Searching..." : "\(searchResult.count) Results") {
                    ForEach(searchResult) { item in
                        NavigationLink(destination: ProductView(archive: item, region: searchRegion)) {
                            ArchivePreviewView(archive: item)
                        }
                    }
                    .transition(.opacity)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring, value: searchResult)
    }

    func buildPickView(for keys: [String], label: () -> some View) -> some View {
        Picker(selection: $searchRegion) {
            ForEach(keys, id: \.self) { key in
                Text("\(key) - \(ApplePackage.Configuration.storeFrontValues[key] ?? String(localized: "Unknown"))")
                    .tag(key)
            }
        } label: {
            label()
        }
    }

    func search() {
        searchKeyFocused = false
        searching = true
        searchInput = "\(searchRegion) - \(searchKey)" + " ..."
        Task {
            do {
                var result = try await ApplePackage.Searcher.search(
                    term: searchKey,
                    countryCode: searchRegion,
                    limit: 32,
                    entityType: searchType
                )
                if let app = try? await ApplePackage.Lookup.lookup(
                    bundleID: searchKey,
                    countryCode: searchRegion
                ) {
                    result.insert(app, at: 0)
                }
                await MainActor.run {
                    searching = false
                    searchResult = result.map { AppStore.AppPackage(software: $0) }
                    searchInput = "\(searchRegion) - \(searchKey)"
                }
            } catch {
                await MainActor.run {
                    searching = false
                    searchResult = []
                    searchInput = "\(searchRegion) - \(searchKey) - Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

extension SearchView {
    var legacyContent: some View {
        content
            .searchable(text: $searchKey, prompt: "Keyword") {}
            .onSubmit(of: .search) { search() }
            .navigationTitle("Search - \(searchRegion.uppercased())")
            .toolbar { tools }
    }
}

// MARK: - Liquid Glass

#if os(iOS)
    @available(iOS 26.0, *)
    extension SearchView {
        var modernContent: some View {
            content
                .searchable(text: $searchKey, placement: searchablePlacement, prompt: "Keyword")
                .onSubmit(of: .search) { search() }
                .toolbarVisibility(navigationBarVisibility, for: .navigationBar)
                .navigationTitle(Text("Search - \(searchRegion.uppercased())"))
                .toolbar {
                    if navigationBarVisibility != .hidden {
                        tools
                    }
                }
                .safeAreaBar(edge: .top) {
                    if navigationBarVisibility == .hidden {
                        HStack {
                            searchTypePicker
                                .buttonStyle(.glass)
                            Spacer()

                            Menu {
                                searchRegionView()
                            } label: {
                                Label(searchRegion, systemImage: "globe")
                            }
                            .menuIndicator(.visible)
                            .buttonStyle(.glass)
                        }
                        .padding([.bottom, .horizontal])
                    }
                }
                .animation(.spring, value: searchResult)
                .animation(.spring, value: searching)
        }

        var navigationBarVisibility: Visibility {
            switch horizontalSizeClass {
            case .compact:
                .hidden
            default:
                .automatic
            }
        }

        var searchablePlacement: SearchFieldPlacement {
            switch horizontalSizeClass {
            case .compact:
                .automatic
            default:
                .toolbar
            }
        }
    }
#endif

#if DEBUG
    private typealias AppPackages = [AppStore.AppPackage]
    extension AppPackages: @retroactive RawRepresentable {
        public init?(rawValue: String) {
            guard
                let data = rawValue.data(using: .utf8),
                let decoded = try? JSONDecoder().decode([AppStore.AppPackage].self, from: data)
            else { return nil }

            self = decoded
        }

        public var rawValue: String {
            guard let data = try? JSONEncoder().encode(self),
                  let rawValue = String(data: data, encoding: .utf8)
            else { return "" }

            return rawValue
        }
    }
#endif

extension ApplePackage.EntityType {
    var iconName: String {
        switch self {
        case .iPhone:
            "iphone"
        case .iPad:
            "ipad"
        }
    }
}
