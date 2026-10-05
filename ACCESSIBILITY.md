# Accessibility

SwiftPermissions' SwiftUI components (`PermissionGate`, `PermissionPrompt`, `PermissionRow`, `PermissionsList`) appear in your app in front of your users, often at a sensitive moment: asking for access to their data. We want them to work for everyone.

## Commitment

- Use standard SwiftUI controls, so buttons are reachable with VoiceOver, Switch Control, Full Keyboard Access and Voice Control.
- Use system text styles, so text follows Dynamic Type.
- Group each row and prompt into a single VoiceOver element where that reads better, and hide purely decorative icons.
- Never show status by colour or icon alone: the status is also written as text.
- Let you replace any of the UI. `PermissionGate` takes a custom fallback view, and the manager works without SwiftUI.

## Supported environments

iOS 15+, macOS 12+, tvOS 15+ and watchOS 9+, with Dark Mode and increased contrast supported through system colours.

## Known limitations

- The components haven't been through a full audit with VoiceOver on every platform yet.
- The text in the components is English only and not yet localised. Pass your own `message:` (or a custom fallback view) to show localised copy.
- System permission prompts themselves are drawn by Apple and are outside this package's control.

## Reporting a barrier

If a component blocks you or your users, please [open an issue](https://github.com/MoElnaggar14/SwiftPermissions/issues/new?template=bug_report.yml) and mention "accessibility" in the title. Tell us the platform, the assistive technology or setting you use, and what happened. Accessibility bugs are treated as bugs, not feature requests.
