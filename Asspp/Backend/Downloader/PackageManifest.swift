//
//  PackageManifest.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/13.
//

import AnyCodable // Moved to Request.swift

import ApplePackage
import Foundation

private let packagesDir = {
    let ret = documentsDirectory.appendingPathComponent("Packages")
    try? FileManager.default.createDirectory(at: ret, withIntermediateDirectories: true)
    return ret
}()

class PackageManifest: ObservableObject, Identifiable, Codable, Hashable, Equatable {
    private(set) var id: UUID = .init()

    private(set) var account: AppStore.UserAccount
    private(set) var package: AppStore.AppPackage

    private(set) var url: URL
    private(set) var signatures: [ApplePackage.Sinf]

    private(set) var creation: Date

    var state: PackageState = .init() {
        didSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    var targetLocation: URL {
        packagesDir
            .appendingPathComponent(package.software.bundleID)
            .appendingPathComponent(package.software.version)
            .appendingPathComponent("\(id.uuidString)")
            .appendingPathExtension("ipa")
    }

    var completed: Bool { state.status == .completed }

    func waitForCompletion(timeout: TimeInterval? = nil) async {
        let start = Date().timeIntervalSince1970
        while true {
            if let timeout, Date().timeIntervalSince1970 - start > timeout {
                return
            }
            try? await Task.sleep(for: .seconds(0.5))
            if [.failed, .completed].contains(state.status) {
                return
            }
        }
    }

    init(account: AppStore.UserAccount, package: AppStore.AppPackage, downloadOutput: ApplePackage.DownloadOutput) {
        self.account = account
        self.package = package
        url = URL(string: downloadOutput.downloadURL)!
        signatures = downloadOutput.sinfs
        creation = .init()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        account = try container.decode(AppStore.UserAccount.self, forKey: .account)
        package = try container.decode(AppStore.AppPackage.self, forKey: .package)
        url = try container.decode(URL.self, forKey: .url)
        signatures = try container.decode([ApplePackage.Sinf].self, forKey: .signatures)
        creation = try container.decode(Date.self, forKey: .creation)
        state = try container.decode(PackageState.self, forKey: .runtime)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(account, forKey: .account)
        try container.encode(package, forKey: .package)
        try container.encode(url, forKey: .url)
        try container.encode(signatures, forKey: .signatures)
        try container.encode(creation, forKey: .creation)
        try container.encode(state, forKey: .runtime)
    }

    private enum CodingKeys: String, CodingKey {
        case id, account, package, url, md5, signatures, metadata, creation, runtime
    }

    static func == (lhs: PackageManifest, rhs: PackageManifest) -> Bool {
        lhs.hashValue == rhs.hashValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(account)
        hasher.combine(package)
        hasher.combine(url)
        hasher.combine(signatures)
        hasher.combine(creation)
        hasher.combine(state)
    }
}

extension PackageManifest {
    func delete() {
        try? FileManager.default.removeItem(at: targetLocation)
        var cleanUpDir = targetLocation.deletingLastPathComponent()
        do {
            while FileManager.default.fileExists(atPath: cleanUpDir.path),
                  try FileManager.default.contentsOfDirectory(atPath: cleanUpDir.path).isEmpty,
                  cleanUpDir.path != packagesDir.path,
                  cleanUpDir.path.count > packagesDir.path.count,
                  cleanUpDir.path.contains(packagesDir.path)
            {
                try? FileManager.default.removeItem(at: cleanUpDir)
                cleanUpDir.deleteLastPathComponent()
            }
        } catch {}
    }
}
