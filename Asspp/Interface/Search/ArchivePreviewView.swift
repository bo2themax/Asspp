//
//  ArchivePreviewView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import Kingfisher
import SwiftUI

struct ArchivePreviewView: View {
    let archive: AppStore.AppPackage
    var preferredIconSize: CGFloat?
    var lineLimit: Int? = 1

    var body: some View {
        HStack(spacing: 8) {
            KFImage(URL(string: archive.software.artworkUrl))
                .antialiased(true)
                .resizable()
                .cornerRadius(0.2184466 * (preferredIconSize ?? 50))
                .frame(width: preferredIconSize ?? 50, height: preferredIconSize ?? 50, alignment: .center)
                .shadow(radius: 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(archive.software.name)
                        .font(.system(.headline, design: .rounded))
                        .lineLimit(2)
                    Spacer()
                    Text(archive.software.version)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text(archive.software.sellerName)
                    .lineLimit(1)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
