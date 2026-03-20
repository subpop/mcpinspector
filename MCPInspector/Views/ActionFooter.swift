// Copyright (c) 2026 Link Dupont
// SPDX-License-Identifier: MIT

import SwiftUI

/// A reusable footer bar with a primary action button and an optional "Clear Result" button.
///
/// Used by `ToolDetailView`, `PromptDetailView`, and `ResourceDetailView` to provide
/// a consistent bottom-bar experience for invoking server operations.
struct ActionFooter: View {
    /// The label shown on the primary button when idle (e.g. "Run", "Read").
    let actionLabel: String

    /// The label shown on the primary button while the action is in progress (e.g. "Running...", "Reading...").
    let activeLabel: String

    /// Whether the action is currently in progress.
    let isActive: Bool

    /// Whether a result exists that can be cleared. Controls visibility of the "Clear Result" button.
    let hasResult: Bool

    /// Called when the user taps the primary action button.
    let onAction: @MainActor () -> Void

    /// Called when the user taps "Clear Result".
    let onClear: @MainActor () -> Void

    var body: some View {
        HStack {
            if hasResult {
                Button("Clear Result") {
                    onClear()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button {
                onAction()
            } label: {
                HStack(spacing: 6) {
                    if isActive {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(isActive ? activeLabel : actionLabel)
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(isActive)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

// MARK: - Previews

#Preview("Idle") {
    ActionFooter(
        actionLabel: "Run",
        activeLabel: "Running...",
        isActive: false,
        hasResult: false,
        onAction: {},
        onClear: {}
    )
}

#Preview("Active") {
    ActionFooter(
        actionLabel: "Run",
        activeLabel: "Running...",
        isActive: true,
        hasResult: false,
        onAction: {},
        onClear: {}
    )
}

#Preview("With Result") {
    ActionFooter(
        actionLabel: "Read",
        activeLabel: "Reading...",
        isActive: false,
        hasResult: true,
        onAction: {},
        onClear: {}
    )
}
