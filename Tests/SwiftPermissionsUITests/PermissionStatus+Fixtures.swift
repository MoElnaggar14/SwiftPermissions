import SwiftPermissionsCore

extension PermissionStatus {
    /// Every status, with every limitation. `PermissionStatus` has no `allCases` in 4.0.
    static let everyStatus: [PermissionStatus] =
        [.notDetermined, .denied, .restricted, .authorized]
            + Limitation.allCases.map(PermissionStatus.limited)
            + [.provisional, .unavailable]
}
