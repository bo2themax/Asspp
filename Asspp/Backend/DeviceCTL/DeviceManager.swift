//
//  DeviceManager.swift
//  Asspp
//
//  Created by luca on 09.10.2025.
//

#if os(macOS)
    import ApplePackage
    import Foundation

    @Observable
    class DeviceManager {
        @Persist(key: "InstalledAppsByDevice", defaultValue: [:])
        @ObservationIgnored
        private var installedApps: [String: Set<InstalledAppInfo>]

        var hint: Hint?

        var devices = [DeviceCTL.Device]()
        var selectedDeviceID: String?

        @MainActor var busyDevices = [DeviceCTL.Device: Process]()

        @MainActor var installingProcess: Process? {
            selectedDevice.flatMap { busyDevices[$0] }
        }

        var selectedDevice: DeviceCTL.Device? {
            devices.first(where: { $0.id == selectedDeviceID })
        }

        func loadDevices() async {
            resetError()
            do {
                let devices = try await DeviceCTL.listDevices()
                    .filter { [.iPad, .iPhone].contains($0.type) }
                    .sorted(by: { $0.lastConnectionDate > $1.lastConnectionDate })
                if selectedDeviceID == nil {
                    selectedDeviceID = devices.first?.id
                }
                self.devices = devices
            } catch {
                updateError(error)
            }
        }

        func install(ipa: URL, to device: DeviceCTL.Device) async -> Bool {
            resetError()
            let process = Process()

            await MainActor.run { busyDevices[device] = process }
            let result: Bool
            do {
                try await DeviceCTL.install(ipa: ipa, to: device, process: process)
                result = true
            } catch {
                updateError(error)
                result = false
            }
            await MainActor.run { busyDevices[device] = nil }
            return result
        }

        func markAppAsInstalled(package: AppStore.AppPackage, account: Account, to device: DeviceCTL.Device) {
            installedApps[device.id, default: []].insert(InstalledAppInfo(
                package: package,
                storeID: account.store,
                region: ApplePackage.Configuration.countryCode(for: account.store) ?? "--",
                accountID: account.appleId
            ))
        }

        func loadApps(for device: DeviceCTL.Device, bundleID: String? = nil) async -> [DeviceCTL.App] {
            resetError()
            let process = Process()
            await MainActor.run { busyDevices[device] = process }
            let apps: [DeviceCTL.App]
            do {
                apps = try await DeviceCTL.listApps(for: device, bundleID: bundleID, process: process)
                    .filter { !$0.hidden && !$0.internalApp && !$0.appClip && $0.removable }
            } catch {
                updateError(error)
                apps = []
            }
            await MainActor.run { busyDevices[device] = nil }
            return apps
        }

        func getInstalledApps(from device: DeviceCTL.Device) async -> [InstalledApp] {
            let installed = await loadInstalledApp(from: device)
            installedApps[device.id] = installed
            return installed.sorted(using: KeyPathComparator(\.package.software.name))
                .map(InstalledApp.init(info:))
        }

        private func loadInstalledApp(from device: DeviceCTL.Device) async -> Set<InstalledAppInfo> {
            let tracked = installedApps[device.id, default: []]
            guard !tracked.isEmpty else { return [] }
            let installed = await loadApps(for: device)
            let updated = installed.compactMap { a in
                if var t = tracked.first(where: { $0.id == a.bundleIdentifier }) {
                    t.package.software.version = a.version
                    return t
                } else {
                    return nil
                }
            }
            return Set(updated)
        }

        func checkForUpdate(_ app: InstalledApp, for device: DeviceCTL.Device) {
            Task {
                let process = Process()
                await MainActor.run {
                    busyDevices[device] = process
                }
                app.state = .checking
                do {
                    try await _checkForUpdate(app, for: device, process: process)
                } catch {
                    logger.warning("failed to update \(app.info.id), error: \(error)")
                    app.state = .error(error.localizedDescription)
                    try? await Task.sleep(for: .seconds(1))
                }
                app.state = .idle
                await MainActor.run {
                    busyDevices[device] = nil
                }
            }
        }

        private func _checkForUpdate(_ app: InstalledApp, for device: DeviceCTL.Device, process: Process) async throws {
            let latest = try await ApplePackage.Lookup.lookup(
                bundleID: app.info.id,
                countryCode: app.info.region
            )

            guard latest.version.compare(app.info.package.software.version, options: [.numeric]) == .orderedDescending else {
                logger.warning("\(app.info.id) is already the latest version")
                throw NSError(
                    domain: #function,
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "No updates",
                    ]
                )
            }
            var updatedApp = app.info
            updatedApp.package = .init(software: latest)
            var request = await Downloads.this.downloadRequest(forArchive: updatedApp.package)
            if request == nil {
                try await Downloads.this.startDownload(for: updatedApp.package, accountID: updatedApp.accountID)
                try await Task.sleep(for: .seconds(1))
                request = await Downloads.this.downloadRequest(forArchive: updatedApp.package)
            }
            guard let request else {
                logger.warning("failed to download \(updatedApp.id)")
                throw NSError(
                    domain: #function,
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Download failed",
                    ]
                )
            }
            app.state = .downloading(request)
            await request.waitForCompletion()
            guard FileManager.default.fileExists(atPath: request.targetLocation.path) else {
                logger.warning("failed to find the file after downloading \(updatedApp.id)")
                throw NSError(
                    domain: #function,
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "iPA not found",
                    ]
                )
            }

            app.state = .installing
            try await DeviceCTL.install(ipa: request.targetLocation, to: device, process: process)
            app.info = updatedApp
            installedApps[device.id, default: []].insert(app.info)
        }

        private func resetError() {
            hint = nil
        }

        private func updateError(_ error: Error) {
            let allErrorDescriptions = ([error] + (error as NSError).underlyingErrors).flatMap(\.failureMessages)

            let errorMessages = allErrorDescriptions.enumerated().map { i, e in
                Array(repeating: "  ", count: i).joined() + "▸" + e
            }
            hint = .init(message: errorMessages.joined(separator: "\n"), color: .red)
        }
    }

    extension DeviceCTL.DeviceType {
        var symbol: String {
            switch self {
            case .iPhone:
                return "iphone"
            case .iPad:
                return "ipad"
            case .appleWatch:
                return "applewatch"
            }
        }

        var osVersionPrefix: String {
            switch self {
            case .iPhone:
                return "iOS"
            case .iPad:
                return "iPadOS"
            case .appleWatch:
                return "watchOS"
            }
        }
    }

    extension Error {
        var failureMessages: [String] {
            [localizedDescription, (self as NSError).userInfo[NSLocalizedFailureReasonErrorKey] as? String].compactMap { $0 }
        }
    }

    extension DeviceManager {
        struct InstalledAppInfo: Codable, Identifiable, Hashable {
            var id: String { package.id }

            var package: AppStore.AppPackage

            let storeID: String
            let region: String

            let accountID: String

            func hash(into hasher: inout Hasher) {
                hasher.combine(id)
            }
        }

        enum UpdateState: Equatable {
            case idle
            case checking
            case downloading(_ manifest: PackageManifest)
            case installing
            case error(_ message: String)
        }

        @Observable class InstalledApp {
            init(info: InstalledAppInfo) {
                self.info = info
            }

            var info: InstalledAppInfo
            var state: UpdateState = .idle
        }
    }
#endif
