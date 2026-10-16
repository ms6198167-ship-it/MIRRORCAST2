# MirrorCast cloud build setup (Windows + Codemagic)

This ZIP adds a starter XcodeGen project definition and a Codemagic workflow to the MirrorCast prototype.

## What this setup does
- Generates `MirrorCast.xcodeproj` on Codemagic's macOS build machine using XcodeGen.
- Attempts an unsigned iOS Simulator build of the SwiftUI app and ReplayKit Broadcast Upload Extension.
- Saves Xcode build logs and simulator build artifacts.

## Important limitations
- This is a **starter configuration**, not a verified successful build. The Swift source has not been compiled by Xcode in this environment.
- The current Swift code uses the placeholder App Group `group.com.example.MirrorCast`. This can compile unsigned but is not a registered entitlement for your account.
- A free Apple Account/Personal Team generally does not provide the App Groups capability required to share receiver settings between the app and Broadcast Upload Extension. Real-device broadcasting may require Apple Developer Program membership and registered App Group capability.
- Simulator build success does not prove ReplayKit screen capture works. Test broadcast behavior on a physical iPhone after signing is configured.
- The prototype transport is unauthenticated and unencrypted. Use only on a trusted private network; do not expose it to the public internet or send sensitive content.
- The generated Xcode project is created during CI and is not checked into source control.

## Upload from Windows
1. Extract this ZIP.
2. Open the extracted `MirrorCast` folder.
3. In your existing GitHub repository, choose **Add file → Upload files**.
4. Upload the contents of this folder (including `project.yml` and `codemagic.yaml`) to the repository root, preserving folders.
5. Commit changes to the default branch.
6. In Codemagic, open the connected app and select the branch containing `codemagic.yaml`.
7. Use **Check for configuration file** if shown, then start the `MirrorCast iOS Simulator Build (unsigned)` workflow.
8. If it fails, download/copy the build log and share the first actual `error:` lines. Do not share secrets or signing credentials.

## Project layout expected at repository root
- `project.yml`
- `codemagic.yaml`
- `MirrorCast/` (Swift sources and config)
- `WindowsReceiver/`
- `Docs/`
- `Tests/`

## Why the workflow is unsigned
This first build checks source/project configuration without requiring Apple signing credentials. It is not an installable iPhone IPA. Device signing/distribution is a separate step.
