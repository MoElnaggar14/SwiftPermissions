# Security Policy

## Supported versions

| Version | Supported |
| --- | --- |
| 3.x | ✅ |
| < 3.0 | ❌ |

## Reporting a vulnerability

**Please don't open a public issue for security problems.**

Report it privately through GitHub: go to the [Security tab](https://github.com/MoElnaggar14/SwiftPermissions/security) and choose **Report a vulnerability** ([direct link](https://github.com/MoElnaggar14/SwiftPermissions/security/advisories/new)). If that isn't available, contact the maintainer, [@MoElnaggar14](https://github.com/MoElnaggar14), privately using the details on their GitHub profile.

Please include:

- The version (or commit) and the products you use.
- What you found, and what an attacker could do with it.
- Steps or a small code sample that reproduces it.

What to expect:

- An acknowledgement within 3 working days.
- An assessment and a plan within 10 working days.
- A fix released as a patch version, with a GitHub security advisory crediting you (unless you'd rather stay anonymous).

## In scope

- A request showing a system prompt without its Info.plist usage description (iOS terminates the app), when `validatesUsageDescriptions` is on.
- A status reported as granted when the user denied it, or the reverse, in a way that could make an app access protected data it shouldn't.
- A core product (`SwiftPermissionsCore`, `SwiftPermissionsUI`, `SwiftPermissions`) linking a privacy framework, which can make App Store review demand usage descriptions an app never needs.
- Crashes or hangs triggered from outside the app.

## Out of scope

- Behaviour of Apple's own permission prompts and TCC.
- Missing usage descriptions in your app's Info.plist (the package reports them; adding them is up to you).
