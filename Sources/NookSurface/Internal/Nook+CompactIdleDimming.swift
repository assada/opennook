// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Glendon Chin - OpenNook modifications
//
// Licensed under the MIT License.
// Modifications license: /LICENSE-MIT-NOOKSURFACE

import SwiftUI

extension Nook {
    /// Reports product activity without opening, closing, or otherwise changing the Nook.
    ///
    /// While compact idle dimming is enabled and the surface is compact, this restores
    /// both slot contents to full opacity and moves the single idle deadline forward.
    /// Calling it while dimming is disabled, expanded, or hidden is a safe no-op.
    public func noteCompactActivity() {
        guard effectiveCompactIdleDimming != nil,
            compactIdleDimmingSurfaceState == .compact
        else { return }
        restoreCompactContentForActivity()
        armCompactIdleDimmingDeadline()
    }

    func handleCompactIdleDimmingStateChange(to newState: NookState) {
        compactIdleDimmingSurfaceState = newState
        guard effectiveCompactIdleDimming != nil else {
            stopCompactIdleDimming()
            return
        }

        switch newState {
            case .compact:
                setCompactContentOpacity(1, animation: nil)
                armCompactIdleDimmingDeadline()
            case .expanded, .hidden:
                stopCompactIdleDimming()
        }
    }

    private var effectiveCompactIdleDimming: NookCompactIdleDimming? {
        guard let compactIdleDimming,
            compactIdleDimming.resolvedDimmedOpacity < 1
        else { return nil }
        return compactIdleDimming
    }

    private func restoreCompactContentForActivity() {
        guard let configuration = effectiveCompactIdleDimming else { return }
        setCompactContentOpacity(1, animation: configuration.restoreAnimation)
    }

    private func armCompactIdleDimmingDeadline() {
        guard let configuration = effectiveCompactIdleDimming else { return }
        compactIdleDimmingDeadline = ContinuousClock.now + configuration.resolvedDelay

        guard compactIdleDimmingTask == nil else { return }
        compactIdleDimmingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let deadline = self?.compactIdleDimmingDeadline else { return }
                let remaining = deadline - ContinuousClock.now

                if remaining > .zero {
                    do {
                        try await Task.sleep(for: remaining)
                    } catch {
                        return
                    }
                    // Activity may have moved the deadline while this worker slept.
                    continue
                }

                guard let self else { return }
                guard self.compactIdleDimmingSurfaceState == .compact,
                    let configuration = self.effectiveCompactIdleDimming
                else {
                    self.compactIdleDimmingDeadline = nil
                    self.compactIdleDimmingTask = nil
                    return
                }

                self.compactIdleDimmingDeadline = nil
                self.compactIdleDimmingTask = nil
                self.setCompactContentOpacity(
                    configuration.resolvedDimmedOpacity,
                    animation: configuration.dimAnimation
                )
                return
            }
        }
    }

    private func stopCompactIdleDimming() {
        compactIdleDimmingDeadline = nil
        compactIdleDimmingTask?.cancel()
        compactIdleDimmingTask = nil
        setCompactContentOpacity(1, animation: nil)
    }

    private func setCompactContentOpacity(
        _ opacity: Double,
        animation: Animation?
    ) {
        guard compactContentOpacity != opacity else { return }
        withAnimation(animation) {
            compactContentOpacity = opacity
        }
    }
}
