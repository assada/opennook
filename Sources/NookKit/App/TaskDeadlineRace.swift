// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Foundation

/// Races an unstructured work task against a deadline without structurally awaiting
/// the losing task. Swift task groups always await every child before their scope exits,
/// so they cannot enforce a hard return deadline when work ignores cancellation.
final class TaskDeadlineRace: @unchecked Sendable {
    enum Outcome {
        case completed
        case timedOut
        case cancelled
    }

    private let lock = NSLock()
    private var outcome: Outcome?
    private var continuation: CheckedContinuation<Outcome, Never>?
    private var workTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    func run(
        timeout: Duration,
        work: @escaping @MainActor @Sendable () async -> Void
    ) async -> Outcome {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                start(continuation: continuation, timeout: timeout, work: work)
            }
        } onCancel: {
            resolve(.cancelled)
        }
    }

    private func start(
        continuation: CheckedContinuation<Outcome, Never>,
        timeout: Duration,
        work: @escaping @MainActor @Sendable () async -> Void
    ) {
        lock.lock()
        if let outcome {
            lock.unlock()
            continuation.resume(returning: outcome)
            return
        }

        self.continuation = continuation
        workTask = Task { @MainActor [weak self] in
            await work()
            self?.resolve(.completed)
        }
        timerTask = Task { [weak self] in
            do {
                try await Task.sleep(for: timeout)
                self?.resolve(.timedOut)
            } catch {
                // The work completed or the caller was cancelled; either path already
                // resolved the continuation and deliberately cancelled this timer.
            }
        }
        lock.unlock()
    }

    private func resolve(_ outcome: Outcome) {
        lock.lock()
        guard self.outcome == nil else {
            lock.unlock()
            return
        }

        self.outcome = outcome
        let continuation = self.continuation
        self.continuation = nil
        let workTask = self.workTask
        let timerTask = self.timerTask
        self.workTask = nil
        self.timerTask = nil
        lock.unlock()

        switch outcome {
            case .completed:
                timerTask?.cancel()
            case .timedOut, .cancelled:
                workTask?.cancel()
                timerTask?.cancel()
        }
        continuation?.resume(returning: outcome)
    }
}
