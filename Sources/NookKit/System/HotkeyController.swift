// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 Glendon Chin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// A copy is included at /LICENSE in the repository root.

import Carbon
import Foundation

/// Registers any number of global hotkeys and routes each to its own handler.
///
/// A multi-module host needs more than one shortcut at a time — the show/hide toggle,
/// a module-cycle key, a direct-jump key per module. Each registration is keyed by a
/// caller-chosen string id so it can be replaced or removed independently; a single
/// shared Carbon event handler dispatches presses to the right handler by hotkey id.
///
/// **Threading.** The controller is `@MainActor`-isolated: `register`/`unregister` and
/// the registration/dispatch dictionaries are only ever touched from the main actor.
/// Carbon delivers `kEventHotKeyPressed` callbacks on the main thread in practice, but
/// that is not contractually guaranteed, so the C event handler does not touch any
/// controller state directly — it hops the lookup-and-dispatch onto the main actor via
/// ``dispatchHandler(forCarbonID:)``. That makes the single-actor invariant provable
/// rather than accidental.
@MainActor
public final class HotkeyController {
    public typealias Handler = () -> Void

    private struct Registration {
        let carbonID: UInt32
        let ref: EventHotKeyRef?
        let handler: Handler
    }

    /// Active registrations, keyed by the caller's string id.
    private var registrations: [String: Registration] = [:]

    /// Handlers keyed by Carbon hotkey id — the dispatch table the event callback uses.
    private var handlersByCarbonID: [UInt32: Handler] = [:]

    private var eventHandler: EventHandlerRef?

    /// Monotonic Carbon hotkey id source. Ids are never recycled: `unregister` removes
    /// the dispatch-table entry, so a stale id can never collide with a live handler,
    /// and `UInt32` gives ~4 billion ids — far more than any session re-registers (the
    /// show/hide key re-registers once per user rebind). Recycling would buy nothing and
    /// risk a freed id being reused while a Carbon event for the old binding is in flight.
    private var nextCarbonID: UInt32 = 1

    /// Nonisolated so it can be used as a default argument / constructed off the main
    /// actor. The initializer only sets stored properties to constants and installs no
    /// Carbon resources; every method that touches mutable state is main-actor isolated.
    public nonisolated init() {}

    deinit {
        // `deinit` is nonisolated, so it cannot touch the main-actor dictionaries. By the
        // time the controller is being freed there are no other references, so a direct,
        // unsynchronized teardown of the Carbon resources is safe here. Carbon's
        // Unregister/RemoveEventHandler are thread-agnostic C calls.
        for registration in registrations.values {
            if let ref = registration.ref {
                UnregisterEventHotKey(ref)
            }
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    /// Registers a global hotkey under `id`, replacing any existing registration for the
    /// same `id`. Carbon `keyCode` is a `kVK_*` virtual key code; `modifiers` is a
    /// Carbon modifier mask (`cmdKey | optionKey | …`). Returns `noErr` on success.
    @discardableResult
    public func register(
        _ id: String,
        keyCode: UInt32,
        modifiers: UInt32,
        handler: @escaping Handler
    ) -> OSStatus {
        unregister(id)

        let handlerStatus = installEventHandlerIfNeeded()
        guard handlerStatus == noErr else { return handlerStatus }

        let carbonID = nextCarbonID
        nextCarbonID += 1

        let hotKeyID = EventHotKeyID(signature: OSType(0x4E4F4F4B), id: carbonID) // "NOOK"
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr else { return status }

        registrations[id] = Registration(carbonID: carbonID, ref: ref, handler: handler)
        handlersByCarbonID[carbonID] = handler
        return noErr
    }

    /// Removes the registration for `id`, if any.
    public func unregister(_ id: String) {
        guard let registration = registrations.removeValue(forKey: id) else { return }
        if let ref = registration.ref {
            UnregisterEventHotKey(ref)
        }
        handlersByCarbonID.removeValue(forKey: registration.carbonID)
    }

    /// Removes every registration and tears down the shared event handler.
    public func unregisterAll() {
        for id in Array(registrations.keys) {
            unregister(id)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    /// Installs the one shared keyboard event handler, lazily. The handler reads the
    /// pressed hotkey's id from the event and dispatches to the matching `Handler`.
    ///
    /// The C callback runs on whatever thread Carbon delivers the event on. It must not
    /// touch ``handlersByCarbonID`` directly — that dictionary is main-actor state. It
    /// only decodes the hotkey id and forwards it to ``dispatchHandler(forCarbonID:)``,
    /// which performs the lookup and invocation on the main actor.
    private func installEventHandlerIfNeeded() -> OSStatus {
        guard eventHandler == nil else { return noErr }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        return InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return noErr }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return noErr }

            let controller = Unmanaged<HotkeyController>.fromOpaque(userData).takeUnretainedValue()
            let carbonID = hotKeyID.id
            // Hop onto the main actor before touching any controller state. If Carbon
            // already delivered on the main thread this still coalesces correctly; if it
            // did not, this is what keeps the dictionary single-actor.
            if Thread.isMainThread {
                MainActor.assumeIsolated { controller.dispatchHandler(forCarbonID: carbonID) }
            } else {
                DispatchQueue.main.async { controller.dispatchHandler(forCarbonID: carbonID) }
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }

    /// Looks up and invokes the handler for a pressed hotkey. Main-actor isolated, so the
    /// dispatch table is provably only ever read here and mutated by register/unregister.
    private func dispatchHandler(forCarbonID carbonID: UInt32) {
        handlersByCarbonID[carbonID]?()
    }
}
