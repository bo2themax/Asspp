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
        static let this = DeviceManager()

        var hint: Hint?

        var installingProcess: Process?
        var devices = [DeviceCTL.Device]()
        var selectedDeviceID: String?

        var selectedDevice: DeviceCTL.Device? {
            devices.first(where: { $0.id == selectedDeviceID })
        }

        func loadDevices() async {
            resetError()
            do {
                devices = try await DeviceCTL.listDevices()
                    .filter { [.iPad, .iPhone].contains($0.type) }
                    .sorted(by: { $0.lastConnectionDate > $1.lastConnectionDate })
                if selectedDeviceID == nil {
                    selectedDeviceID = devices.first?.id
                }
            } catch {
                updateError(error)
            }
        }

        func install(ipa: URL, to device: DeviceCTL.Device) async -> Bool {
            resetError()
            let process = Process()
            installingProcess = process
            defer { installingProcess = nil }
            do {
                try await DeviceCTL.install(ipa: ipa, to: device, process: process)
                return true
            } catch {
                updateError(error)
                return false
            }
        }

        func loadApps(for device: DeviceCTL.Device, bundleID: String? = nil) async -> [DeviceCTL.App] {
            resetError()
            do {
                let apps = try await DeviceCTL.listApps(for: device, bundleID: bundleID)
                    .filter { !$0.hidden && !$0.internalApp && !$0.appClip && $0.removable }
                return apps
            } catch {
                updateError(error)
                return []
            }
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
#endif
