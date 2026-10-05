#!/usr/bin/env python3
"""Check that an app declares the Info.plist usage descriptions its SwiftPermissions setup needs.

Scans Swift sources for SwiftPermissions product imports and registrations, then looks
for usage-description keys in Info.plist files, INFOPLIST_KEY_* build settings
(project.pbxproj) and .xcconfig files. Reports:

  * registered permissions whose usage description is missing   (error)
  * registrations whose product is never imported                (error)
  * products imported but never registered                       (warning: App Review
    still scans the linked framework and may ask for its usage description)

Usage: check_usage_descriptions.py [PROJECT_ROOT] [--ios-deployment-target N]
Exit status: 0 when nothing is missing, 1 otherwise. Standard library only.
"""
import argparse
import plistlib
import re
import sys
from pathlib import Path

# registration -> (product, required keys on iOS 17+, extra keys below iOS 17)
PERMISSIONS = {
    "camera": ("SwiftPermissionsCamera", ["NSCameraUsageDescription"], []),
    "microphone": ("SwiftPermissionsCamera", ["NSMicrophoneUsageDescription"], []),
    "photoLibrary": ("SwiftPermissionsPhotos", ["NSPhotoLibraryUsageDescription"], []),
    "photoLibraryAddOnly": ("SwiftPermissionsPhotos", ["NSPhotoLibraryAddUsageDescription"], []),
    "contacts": ("SwiftPermissionsContacts", ["NSContactsUsageDescription"], []),
    "calendar": ("SwiftPermissionsCalendar", ["NSCalendarsFullAccessUsageDescription"], ["NSCalendarsUsageDescription"]),
    "calendarWriteOnly": ("SwiftPermissionsCalendar", ["NSCalendarsWriteOnlyAccessUsageDescription"], ["NSCalendarsUsageDescription"]),
    "reminders": ("SwiftPermissionsCalendar", ["NSRemindersFullAccessUsageDescription"], ["NSRemindersUsageDescription"]),
    "locationWhenInUse": ("SwiftPermissionsLocation", ["NSLocationWhenInUseUsageDescription"], []),
    "locationAlways": ("SwiftPermissionsLocation", ["NSLocationWhenInUseUsageDescription", "NSLocationAlwaysAndWhenInUseUsageDescription"], []),
    "notifications": ("SwiftPermissionsCore", [], []),
    "bluetooth": ("SwiftPermissionsBluetooth", ["NSBluetoothAlwaysUsageDescription"], []),
    "tracking": ("SwiftPermissionsTracking", ["NSUserTrackingUsageDescription"], []),
    "speechRecognition": ("SwiftPermissionsSpeech", ["NSSpeechRecognitionUsageDescription"], []),
    "motion": ("SwiftPermissionsMotion", ["NSMotionUsageDescription"], []),
    "siri": ("SwiftPermissionsSiri", ["NSSiriUsageDescription"], []),
    "mediaLibrary": ("SwiftPermissionsMediaLibrary", ["NSAppleMusicUsageDescription"], []),
    "biometrics": ("SwiftPermissionsBiometrics", ["NSFaceIDUsageDescription"], []),
    "health": ("SwiftPermissionsHealth", ["NSHealthShareUsageDescription"], []),
}
# Products that also contain or re-export Core.
CORE_PRODUCTS = {"SwiftPermissions", "SwiftPermissionsCore", "SwiftPermissionsUI"}
SKIP_DIRS = {".build", "build", "DerivedData", "Pods", "Carthage", ".git", "SourcePackages", "checkouts"}

IMPORT_RE = re.compile(r"^\s*(?:@\w+\s+)*import\s+(SwiftPermissions\w*)", re.M)
# The argument list of PermissionManager(permissions: [...]) / PermissionStore(permissions: [...]).
REGISTRATION_LIST_RE = re.compile(r"\b(?:PermissionManager|PermissionStore)\s*\(\s*permissions\s*:\s*\[", re.S)
MEMBER_RE = re.compile(r"(?<![\w)\]])\.(\w+)")


def walk(root, suffixes):
    for path in root.rglob("*"):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.is_file() and path.suffix in suffixes:
            yield path


def balanced_list(text, start):
    """Text of the [...] literal whose '[' is at text[start - 1]."""
    depth, i = 1, start
    while i < len(text) and depth:
        depth += {"[": 1, "]": -1}.get(text[i], 0)
        i += 1
    return text[start:i - 1]


def scan_swift(root):
    imports, registered = set(), set()
    for path in walk(root, {".swift"}):
        text = path.read_text(errors="ignore")
        in_test_dir = any(part.endswith(("Tests", "UITests")) for part in path.relative_to(root).parts[:-1])
        if in_test_dir or path.stem.endswith("Tests") or re.search(r"^\s*import\s+(XCTest|Testing)\b", text, re.M):
            continue  # tests register stubs; they don't need usage descriptions
        imports.update(IMPORT_RE.findall(text))
        for match in REGISTRATION_LIST_RE.finditer(text):
            body = balanced_list(text, match.end())
            registered.update(m for m in MEMBER_RE.findall(body) if m in PERMISSIONS)
    return imports, registered


def declared_keys(root):
    keys = set()
    for path in walk(root, {".plist"}):
        try:
            with path.open("rb") as handle:
                data = plistlib.load(handle)
        except Exception:
            continue
        if isinstance(data, dict):
            keys.update(k for k, v in data.items() if isinstance(v, str) and v.strip())
    for path in walk(root, {".pbxproj", ".xcconfig"}):
        text = path.read_text(errors="ignore")
        for key, value in re.findall(r"INFOPLIST_KEY_(NS\w+UsageDescription)\s*=\s*([^;\n]*)", text):
            if value.strip().strip('"').strip():
                keys.add(key)
    return keys


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--ios-deployment-target", type=float, default=17,
                        help="require the pre-iOS 17 calendar/reminders keys when below 17")
    args = parser.parse_args()
    root = Path(args.root).resolve()

    imports, registered = scan_swift(root)
    keys = declared_keys(root)
    errors, warnings = [], []

    for name in sorted(registered):
        product, required, legacy = PERMISSIONS[name]
        needed = required + (legacy if args.ios_deployment_target < 17 else [])
        if name == "health":
            needed = []  # depends on share:/read:; at least one of the two keys
            if not {"NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"} & keys:
                errors.append(".health: add NSHealthShareUsageDescription (read) and/or NSHealthUpdateUsageDescription (share)")
        missing = [k for k in needed if k not in keys]
        if missing:
            errors.append(f".{name}: missing {', '.join(missing)}")
        has_product = product in imports or (product == "SwiftPermissionsCore" and imports & CORE_PRODUCTS)
        if not has_product:
            errors.append(f".{name}: add the {product} product and `import {product}`")

    used_products = {PERMISSIONS[n][0] for n in registered}
    for product in sorted(imports - CORE_PRODUCTS - {"SwiftPermissionsTesting"}):
        if product not in used_products:
            warnings.append(f"{product} is imported but none of its permissions is registered; "
                            "remove the product if you don't request it")

    print(f"Registered: {', '.join('.' + n for n in sorted(registered)) or 'none found'}")
    for line in warnings:
        print(f"warning: {line}")
    for line in errors:
        print(f"error: {line}")
    if not registered:
        print("note: no PermissionManager(permissions:) / PermissionStore(permissions:) call found; "
              "registrations built elsewhere (e.g. a variable) aren't detected")
    if not errors:
        print("OK: every registered permission has its usage description.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
