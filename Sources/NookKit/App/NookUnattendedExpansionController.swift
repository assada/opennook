// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// Owns the single movable deadline for an unattended expansion.
///
/// Coordinator lifecycle and interaction publishers decide when to arm or cancel it;
/// this type only guarantees that deadline refreshes reuse one worker and that a stale
/// worker cannot fire after cancellation.
@MainActor
final class NookUnattendedExpansionController {
    private(set) var deadline: ContinuousClock.Instant?
    private(set) var workerTask: Task<Void, Never>?
    private var timeoutAction: (@MainActor () -> Void)?

    var isArmed: Bool { deadline != nil }

    /// Arms a new unattended cycle or moves the current cycle's deadline forward.
    /// Re-arming while a worker is live reuses that worker.
    func arm(
        after timeout: Duration,
        onTimeout: @escaping @MainActor () -> Void
    ) {
        deadline = ContinuousClock.now + max(timeout, .zero)
        timeoutAction = onTimeout

        guard workerTask == nil else { return }
        workerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let deadline = self?.deadline else { return }
                let remaining = deadline - ContinuousClock.now

                if remaining > .zero {
                    do {
                        try await Task.sleep(for: remaining)
                    } catch {
                        return
                    }
                    // A repeated unattended presentation may have moved the deadline.
                    continue
                }

                guard let self else { return }
                let action = self.timeoutAction
                self.deadline = nil
                self.timeoutAction = nil
                self.workerTask = nil
                action?()
                return
            }
        }
    }

    /// Moves an already-armed deadline immediately, before a queued lifecycle operation
    /// reaches the surface. A non-armed controller stays idle.
    func postponeIfArmed(by timeout: Duration) {
        guard isArmed else { return }
        deadline = ContinuousClock.now + max(timeout, .zero)
    }

    /// Ends the unattended cycle. Idempotent and safe from every lifecycle edge.
    func cancel() {
        deadline = nil
        timeoutAction = nil
        workerTask?.cancel()
        workerTask = nil
    }
}
