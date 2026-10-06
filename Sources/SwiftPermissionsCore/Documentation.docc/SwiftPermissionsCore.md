# ``SwiftPermissionsCore``

One async API for every Apple permission.

## Overview

The core module models permissions as a small domain:

- A ``Permission`` identifies a capability (camera, contacts, or one you define).
- A ``PermissionStatus`` is the user's decision, normalised across frameworks.
- A ``PermissionProvider`` knows how one permission is read and requested on this platform.
- ``PermissionManager`` coordinates the providers. It validates Info.plist keys, coalesces concurrent prompts and publishes changes.

Each system framework is a separate product (`SwiftPermissionsCamera`,
`SwiftPermissionsLocation`, …) that adds a ``PermissionRegistration``. Link and register
only the permissions you request: App Store review asks for the usage description of
every permission whose request API is in your binary.

```swift
import SwiftPermissionsCamera

let permissions = PermissionManager(permissions: [.camera, .notifications])
let status = try await permissions.request(.camera)
```

## Topics

### Essentials

- ``PermissionManager``
- ``Permission``
- ``PermissionStatus``
- ``PermissionError``

### Depending on abstractions

- ``PermissionManaging``
- ``PermissionStatusReading``
- ``PermissionRequesting``
- ``PermissionObserving``

### Registering permissions

- ``PermissionRegistration``

### Extending

- ``PermissionProvider``
- ``PermissionProviderRegistry``
- ``UsageDescriptionSource``
- ``InfoPlist``

### Remembering requests

- ``PermissionRequestHistory``
- ``InMemoryRequestHistory``
- ``UserDefaultsRequestHistory``

### Results

- ``PermissionBatchResult``
- ``PermissionChange``

### Settings

- ``AppSettings``
