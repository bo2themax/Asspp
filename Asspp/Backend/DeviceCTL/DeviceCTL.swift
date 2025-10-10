//
//  DeviceCTL.swift
//  Asspp
//
//  Created by luca on 09.10.2025.
//

#if os(macOS)
    import AnyCodable
    import Foundation

    enum DeviceCTL {
        private static let executablePath = "/Library/Developer/PrivateFrameworks/CoreDevice.framework/Versions/A/Resources/bin/devicectl"

        private static func run(_ args: [String], process: Process = Process()) throws -> Bool {
            guard FileManager.default.fileExists(atPath: executablePath) else {
                throw NSError(domain: "com.apple.dt.CoreDeviceError", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "Installer not found, please make sure Xcode is installed once", comment: "CoreDeviceError when devicectl is not found"),
                ])
            }
            do {
                process.executableURL = URL(filePath: executablePath)
                process.arguments = args
                try process.run()
                process.waitUntilExit()
                guard
                    process.terminationReason == .exit
                else {
                    logger.error("devicectl exited with error")
                    // could be terminated by user
                    return false
                }
                // skip checking status to read error from devicectl
                return true
            } catch {
                logger.error("devicectl exited with error: \(error)")
                return false
            }
        }

        private static func getJson(_ args: [String], process: Process = Process()) throws -> AnyCodable {
            let tempo = FileManager.default.temporaryDirectory
            let filename = UUID().uuidString
            let temporaryJsonFile = tempo
                .appendingPathComponent(filename)
                .appendingPathExtension("json")
            defer {
                try? FileManager.default.removeItem(at: temporaryJsonFile)
            }
            let arguments = args + [
                "-j", "tmp/\(filename).json", // will be prefixed with sandbox path by system
                "-q",
            ]
            guard try run(arguments, process: process) else {
                return AnyCodable(nil)
            }
            let jsonData = try Data(contentsOf: temporaryJsonFile)
            return try JSONDecoder().decode(AnyCodable.self, from: jsonData)
        }
    }

    // MARK: - interface

    extension DeviceCTL {
        @concurrent
        static func listDevices() async throws -> [Device] {
            let result = try getJson(["list", "devices"])
            if let error = NSError(codable: result["error"]) {
                throw error
            }
            let devices = result["result"]["devices"].asArray().compactMap(Device.init(_:))
            return devices
        }

        static func install(ipa: URL, to device: Device, process: Process) async throws {
            let arguments = [
                "device", "install", "app",
                "-d", device.id,
                ipa.path,
            ]
            let codable = try getJson(arguments, process: process)

            if let error = NSError(codable: codable["error"]) {
                throw error
            }
        }

        @concurrent
        static func listApps(for device: Device, bundleID: String? = nil) async throws -> [App] {
            var arguments: [String] = "device info apps --include-all-apps -d \(device.id)".split(separator: " ").map(String.init(_:))
            if let bundleID {
                arguments.append(contentsOf: [
                    "--bundle-id", bundleID,
                ])
            }
            let codable = try getJson(arguments)
            if let error = NSError(codable: codable["error"]) {
                throw error
            }
            let apps = codable["result"]["apps"].asArray().compactMap(App.init(_:))
            return apps
        }
        /*
            @concurrent
            static func getAppIcon(for app: App, device: Device, update: Bool = false) async throws -> URL {
                let filename = "icon_\(device.id)"
                let packageFolder = PackageManifest.packageLocation(for: app.id, version: app.version)
                try? FileManager.default.createDirectory(at: packageFolder, withIntermediateDirectories: true)
                let iconFile = packageFolder
                    .appendingPathComponent(filename)
                    .appendingPathExtension("png")
                guard update || !FileManager.default.fileExists(atPath: iconFile.path) else {
                    return iconFile
                }
                let arguments = [
                    "device", "info", "appIcon",
                    "-d", device.id,
                    "--allow-placeholder", "false",
                    "--app-bundle-id", app.bundleIdentifier,
                    "--width", "1024", "--height", "1024",
                    "--scale", "1",
                    "--destination", iconFile.path, // will NOT be prefixed
                ]
                guard let codable: AnyCodable = getJson(arguments) else {
                    return iconFile
                }

                if let error = NSError(codable: codable["error"]) {
                    throw error
                }
                return iconFile
            }
         */
    }

    extension NSError {
        convenience init?(codable: AnyCodable) {
            guard
                let code = codable["code"].value as? Int,
                let domain = codable["domain"].value as? String
            else {
                return nil
            }
            self.init(domain: domain, code: code, userInfo: [
                NSLocalizedDescriptionKey: codable["userInfo"][NSLocalizedDescriptionKey]["string"].value,
                NSLocalizedFailureReasonErrorKey: codable["userInfo"][NSLocalizedFailureReasonErrorKey]["string"].value,
                NSUnderlyingErrorKey: NSError(codable: codable["userInfo"]["NSUnderlyingError"]["error"]) as Any,
            ])
        }
    }

    // MARK: - list devices

    extension DeviceCTL {
        enum DeviceType: String {
            case iPhone, iPad, appleWatch // unsure of vision pro
        }

        struct Device: Identifiable, Hashable, Sendable {
            init(id: String, name: String, model: String, type: DeviceCTL.DeviceType, osVersionNumber: String, osBuildUpdate: String, lastConnectionDate: String) {
                self.id = id
                self.name = name
                self.model = model
                self.type = type
                self.osVersionNumber = osVersionNumber
                self.osBuildUpdate = osBuildUpdate
                self.lastConnectionDate = ISO8601DateFormatter().date(from: lastConnectionDate) ?? Date()
            }

            let id: String
            let name: String
            let model: String
            let type: DeviceType
            let osVersionNumber: String // 26.0
            let osBuildUpdate: String // 23A341
            let lastConnectionDate: Date

            init?(_ codable: AnyCodable) {
                let deviceProperties = codable["deviceProperties"]
                let connectionProperties = codable["connectionProperties"]
                let hardwareProperties = codable["hardwareProperties"]
                guard
                    connectionProperties["tunnelState"] != "unavailable",
                    connectionProperties["pairingState"] == "paired",
                    let lastConnectionDate = connectionProperties["lastConnectionDate"].value as? String,
                    let id = codable["identifier"].value as? String,
                    let name = deviceProperties["name"].value as? String,
                    let model = hardwareProperties["marketingName"].value as? String,
                    let type = (hardwareProperties["deviceType"].value as? String).flatMap(DeviceType.init(rawValue:)),
                    let osVersionNumber = deviceProperties["osVersionNumber"].value as? String,
                    let osBuildUpdate = deviceProperties["osBuildUpdate"].value as? String
                else {
                    return nil
                }
                self.init(id: id, name: name, model: model, type: type, osVersionNumber: osVersionNumber, osBuildUpdate: osBuildUpdate, lastConnectionDate: lastConnectionDate)
            }
        }
    }

    // MARK: - device info apps --include-all-apps

    extension DeviceCTL {
        struct App: Identifiable, Hashable, Codable, Sendable {
            let id: String
            let name: String
            let bundleIdentifier: String
            let version: String
            let bundleVersion: String
            let appClip: Bool
            let builtByDeveloper: Bool
            let defaultApp: Bool
            let hidden: Bool
            let internalApp: Bool
            let removable: Bool
            let url: String

            init(id: String, name: String, bundleIdentifier: String, version: String, bundleVersion: String, appClip: Bool, builtByDeveloper: Bool, defaultApp: Bool, hidden: Bool, internalApp: Bool, removable: Bool, url: String) {
                self.id = id
                self.name = name
                self.bundleIdentifier = bundleIdentifier
                self.version = version
                self.bundleVersion = bundleVersion
                self.appClip = appClip
                self.builtByDeveloper = builtByDeveloper
                self.defaultApp = defaultApp
                self.hidden = hidden
                self.internalApp = internalApp
                self.removable = removable
                self.url = url
            }

            init?(_ codable: AnyCodable) {
                guard
                    let bundleIdentifier = codable["bundleIdentifier"].value as? String,
                    let name = codable["name"].value as? String,
                    let version = codable["version"].value as? String,
                    let bundleVersion = codable["bundleVersion"].value as? String,
                    let appClip = codable["appClip"].value as? Bool,
                    let builtByDeveloper = codable["builtByDeveloper"].value as? Bool,
                    let defaultApp = codable["defaultApp"].value as? Bool,
                    let hidden = codable["hidden"].value as? Bool,
                    let internalApp = codable["internalApp"].value as? Bool,
                    let removable = codable["removable"].value as? Bool,
                    let url = codable["url"].value as? String
                else {
                    return nil
                }
                self.init(
                    id: bundleIdentifier,
                    name: name,
                    bundleIdentifier: bundleIdentifier,
                    version: version,
                    bundleVersion: bundleVersion,
                    appClip: appClip,
                    builtByDeveloper: builtByDeveloper,
                    defaultApp: defaultApp,
                    hidden: hidden,
                    internalApp: internalApp,
                    removable: removable,
                    url: url
                )
            }
        }
    }

    private extension AnyCodable {
        subscript(key: String) -> AnyCodable {
            guard let dictionary = value as? [String: Any] else {
                return AnyCodable(nilLiteral: ())
            }
            return AnyCodable(dictionary[key])
        }

        func decodeAs<T: Decodable>(as type: T.Type) throws -> T? {
            let data = try JSONEncoder().encode(self)
            return try JSONDecoder().decode(type.self, from: data)
        }

        func asArray() -> [AnyCodable] {
            (value as? [Any])?.map(AnyCodable.init(_:)) ?? []
        }
    }
#endif
