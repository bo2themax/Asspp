//
//  View+Redacted.swift
//  Asspp
//
//  Created by luca on 17.09.2025.
//

import SwiftUI

extension View {
    @ViewBuilder
    func redacted(reason: RedactionReasons, isEnabled: Bool) -> some View {
        if isEnabled {
            Text("88888888888")
                .redacted(reason: reason)
        } else {
            self
        }
    }
}
