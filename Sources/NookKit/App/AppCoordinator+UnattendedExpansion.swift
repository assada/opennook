// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Combine
import NookSurface

extension AppCoordinator {
    /// Keeps unattended timing attached to authoritative surface lifecycle and
    /// interaction signals rather than any ephemeral SwiftUI view.
    func bindUnattendedExpansion() {
        surface.statePublisher
            .filter { $0 != .expanded }
            .sink { [weak self] _ in
                self?.unattendedExpansionController.cancel()
            }
            .store(in: &cancellables)

        surface.isHoveringPublisher
            .filter { $0 }
            .sink { [weak self] _ in
                self?.unattendedExpansionController.cancel()
            }
            .store(in: &cancellables)

        surface.isDragInFlightPublisher
            .filter { $0 }
            .sink { [weak self] _ in
                self?.unattendedExpansionController.cancel()
            }
            .store(in: &cancellables)

        presentationPinning.pinChanges
            .filter { $0 }
            .sink { [weak self] _ in
                self?.unattendedExpansionController.cancel()
            }
            .store(in: &cancellables)
    }

    /// Applies one expansion's ownership semantics, then arms unattended timing only
    /// after the surface is visibly expanded and still unengaged.
    func expandNook(presentation: NookExpansionBehavior) async {
        switch presentation {
            case .userInitiated:
                unattendedExpansionController.cancel()
                setUserInitiatedOpen(true)
            case .unattended:
                // An automatic result arriving while the user already owns the surface
                // updates the content without converting their session into a timeout.
                guard !hasAcknowledgedCurrentExpansion else {
                    unattendedExpansionController.cancel()
                    await surface.expand(on: nil)
                    return
                }
                setUserInitiatedOpen(false)
        }

        surface.staysExpandedOnHoverExit = appState.keepNookOpen
        await surface.expand(on: nil)

        guard let timeout = presentation.unattendedTimeout,
            canArmUnattendedExpansion
        else { return }

        unattendedExpansionController.arm(after: timeout) { [weak self] in
            self?.enqueueUnattendedAutoCompact()
        }
    }

    /// Refreshes an existing unattended preview as soon as another automatic result asks
    /// to present, preventing its old deadline from racing the queued expansion.
    func prepareQueuedExpansion(_ presentation: NookExpansionBehavior) {
        switch presentation {
            case .userInitiated:
                unattendedExpansionController.cancel()
            case .unattended(let timeout):
                unattendedExpansionController.postponeIfArmed(by: timeout)
        }
    }

    private var hasAcknowledgedCurrentExpansion: Bool {
        userInitiatedOpen
            || surface.isHovering
            || surface.isDragInFlight
            || presentationPinning.isPinned
    }

    private var canArmUnattendedExpansion: Bool {
        surface.state == .expanded
            && !hasAcknowledgedCurrentExpansion
            && !appState.keepNookOpen
    }

    /// Re-enters the one serial lifecycle chain. The live guards are repeated there so
    /// hover/pinning that lands on the same turn as the deadline always wins.
    private func enqueueUnattendedAutoCompact() {
        enqueueLifecycle { [weak self] in
            guard let self,
                self.surface.state == .expanded,
                !self.hasAcknowledgedCurrentExpansion,
                !self.appState.keepNookOpen
            else { return }

            self.setUserInitiatedOpen(false)
            await self.surface.compact(on: nil)
        }
    }
}
