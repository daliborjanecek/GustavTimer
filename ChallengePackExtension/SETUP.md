# Background Assets Extension – Xcode Setup

This directory contains the source for the **ChallengePackExtension** target.
The Xcode target itself must be added in Xcode (Apple's project format makes
adding new targets via text edits unsafe). Once added, drop the files in this
directory into the new target.

## Steps

1. In Xcode: **File → New → Target… → Background Assets Extension**.
2. Name it `ChallengePackExtension`. Bundle id:
   `cz.daliborjanecek.GustavTimer.ChallengePackExtension`.
3. Replace the auto-generated files with:
   - `ChallengePackExtension.swift`
   - `Info.plist`
   - `ChallengePackExtension.entitlements`
4. In **Signing & Capabilities** for the new target add:
   - **App Groups** → `group.cz.daliborjanecek.GustavTimer`
   - **Background Assets** capability (it's added automatically with the
     extension template).
5. Set **iOS Deployment Target** to `26.0` for the extension target.
6. Embed the extension in the host app: select the `GustavTimer` target →
   **General → Frameworks, Libraries, and Embedded Content** → add
   `ChallengePackExtension.appex` (Embed Without Signing → Embed & Sign).
7. Build with **iOS 26.0+** simulator/device.

## Asset pack workflow

See `../ChallengePackAssets/README.md` for the `xcrun ba-package` packaging
and App Store Connect upload steps.
