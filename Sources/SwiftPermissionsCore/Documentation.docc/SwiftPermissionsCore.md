# ``SwiftPermissionsCore``

One async API for every Apple permission.

## Overview

The core module models permissions as a small domain:

- A ``Permission`` identifies a capability (camera, contacts, or one you define).
- A ``PermissionStatus`` is the user's decision, normalised across frameworks.
- A ``PermissionProvider`` knows how one permission is read and requested on this platform.
- ``PermissionManager`` coordinates the providers. It validates Info.plist keys, coalesces concurrent prompts and publishes changes.

```swift
let permissions = PermissionManager()
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

### Extending

- ``PermissionProvider``
- ``PermissionProviderRegistry``
- ``UsageDescriptionSource``
- ``InfoPlist``

### Results

- ``PermissionBatchResult``
- ``PermissionChange``

### Settings

- ``AppSettings``
