import ApplePackage
import Kingfisher
import SwiftUI

@available(iOS, unavailable)
struct InstalledListView: View {
    @State var vm = DeviceManager()
    @State private var isLoading = false
    @State private var pendingUpdates: [DeviceCTL.Device: Set<Software>] = [:]

    var body: some View {
        NavigationStack {
            FormOnTahoeList {
                ForEach(vm.devices) {
                    DeviceSection(vm: vm, device: $0)
                }
            }
            .disabled(isLoading)
        }
        .toolbar {
            ToolbarItem {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                }
            }
            .hideSharedBackground()
        }
        .task {
            isLoading = true
            await vm.loadDevices()
            isLoading = false
        }
    }
}

private struct DeviceSection: View {
    let vm: DeviceManager
    let device: DeviceCTL.Device
    @State var installedApps = [DeviceManager.InstalledApp]()
    var body: some View {
        Section {
            ForEach(installedApps, id: \.info) { app in
                AppRow(app: app) {
                    vm.checkForUpdate(app, for: device)
                }
            }
            Text("\(installedApps.count) apps installed by Asspp")
        } header: {
            HStack {
                Label(device.name, systemImage: device.type.symbol)
                Spacer()
                if vm.busyDevices[device] != nil {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                }
            }
            .task {
                installedApps = await vm.getInstalledApps(from: device)
            }
        }
    }
}

private struct AppRow: View {
    @StateObject var vm = AppStore.this
    var preferredIconSize: CGFloat? { 50 }
    let app: DeviceManager.InstalledApp
    let action: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            KFImage(URL(string: app.info.package.software.artworkUrl))
                .antialiased(true)
                .resizable()
                .cornerRadius(0.2184466 * (preferredIconSize ?? 50))
                .frame(width: preferredIconSize ?? 50, height: preferredIconSize ?? 50, alignment: .center)
                .shadow(radius: 1)
            VStack(alignment: .leading) {
                Text(app.info.package.software.name)
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(2)
                Text(app.info.package.software.version)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(String([app.info.region, app.info.accountID].joined(by: " - ")))
                    .redacted(reason: .placeholder, isEnabled: vm.demoMode)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                action()
            } label: {
                switch app.state {
                case .idle, .error:
                    Text("Update")
                case .checking:
                    Text("Checking")
                case let .downloading(manifest):
                    Text("Downloading \(manifest.state.percent * 100, specifier: "%.02f")%")
                case .installing:
                    Text("Installing")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(app.state != .idle)
        }
        .overlay {
            if case let .error(message) = app.state {
                Text(message)
                    .foregroundStyle(.red)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.smooth, value: app.state)
    }
}
