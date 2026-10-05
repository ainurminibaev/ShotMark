import Carbon

/// Global hotkey through Carbon: works without Accessibility permission.
final class HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var handlerInstalled = false

    private let id: UInt32
    private var ref: EventHotKeyRef?

    init(id: UInt32) {
        self.id = id
    }

    deinit {
        unregister()
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> OSStatus {
        unregister()
        HotKey.installHandlerIfNeeded()
        HotKey.handlers[id] = handler
        let hotKeyID = EventHotKeyID(signature: OSType(0x5348_4D4B), id: id) // 'SHMK'
        return RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref {
            UnregisterEventHotKey(ref)
        }
        ref = nil
        HotKey.handlers[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
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
            if status == noErr {
                let id = hotKeyID.id
                DispatchQueue.main.async { HotKey.handlers[id]?() }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
