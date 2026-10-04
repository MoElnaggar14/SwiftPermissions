public extension PermissionProviderRegistry {
    /// A provider for every system permission available on the current platform.
    ///
    /// ``Permission/health`` isn't included because it needs the data types you use;
    /// register a ``HealthPermissionProvider`` for it.
    static var standard: PermissionProviderRegistry {
        var providers: [any PermissionProvider] = [
            NotificationsPermissionProvider(),
            LocationPermissionProvider.whenInUse,
            BluetoothPermissionProvider()
        ]
        #if !os(tvOS)
        providers.append(LocationPermissionProvider.always)
        #endif
        #if os(iOS) || os(macOS) || os(visionOS)
        providers += [
            CaptureDevicePermissionProvider.camera,
            CaptureDevicePermissionProvider.microphone,
            PhotoLibraryPermissionProvider.readWrite,
            PhotoLibraryPermissionProvider.addOnly,
            SpeechRecognitionPermissionProvider(),
            BiometricsPermissionProvider()
        ]
        #endif
        #if os(iOS) || os(macOS) || os(watchOS) || os(visionOS)
        providers += [
            ContactsPermissionProvider(),
            EventKitPermissionProvider.calendar,
            EventKitPermissionProvider.calendarWriteOnly,
            EventKitPermissionProvider.reminders
        ]
        #endif
        #if os(iOS) || os(watchOS)
        providers += [MotionPermissionProvider(), SiriPermissionProvider()]
        #endif
        #if os(iOS)
        providers.append(MediaLibraryPermissionProvider())
        #endif
        #if canImport(AppTrackingTransparency) && !os(watchOS)
        providers.append(TrackingPermissionProvider())
        #endif
        return PermissionProviderRegistry(providers)
    }
}
