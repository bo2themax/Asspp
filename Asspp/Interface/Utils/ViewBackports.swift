//
//  ViewBackports.swift
//  Asspp
//
//  Created by luca on 19.09.2025.
//

import SwiftUI

extension View {
    @ViewBuilder
    func mediumAndLargeDetents() -> some View {
        #if os(iOS)
            if #available(iOS 16.0, *) {
                presentationDetents([.medium, .large])
            } else {
                self
            }
        #else
            self
        #endif
    }

    @ViewBuilder
    func neverMinimizeTab() -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                tabBarMinimizeBehavior(.never)
            } else {
                self
            }
        #else
            self
        #endif
    }

    @ViewBuilder
    func activateSearchWhenSearchTabSelected() -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                tabViewSearchActivation(.searchTabSelection)
            } else {
                self
            }
        #else
            self
        #endif
    }

    @ViewBuilder
    func sidebarAdaptableTabView() -> some View {
        #if os(iOS)
            if #available(iOS 26.0, *) {
                tabViewStyle(.sidebarAdaptable)
            } else {
                self
            }
        #else
            self
        #endif
    }

    @ViewBuilder
    func onChangeCompat<Value: Equatable>(
        of value: Value,
        initial: Bool = false,
        perform action: @escaping (Value) -> Void
    ) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            onChange(of: value, initial: initial) { _, newValue in
                action(newValue)
            }
        } else {
            onChange(of: value, perform: action)
        }
    }
}
