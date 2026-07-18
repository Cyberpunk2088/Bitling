iOS Export and Xcode Integration (README)

This guide explains the steps to export and sign the Bitling project for iOS (Xogot) using Godot 4 and Xcode.

Prerequisites
- macOS with Xcode installed
- Godot 4 editor and iOS export templates
- Apple Developer account with provisioning profiles and certificates

Steps
1. Install Godot 4 and the iOS export templates.
2. In Godot Editor, open project.godot and go to Project -> Export.
3. Add a new iOS preset (you can use the provided skeleton in export_presets.cfg as a starting point).
4. Configure the export preset: set the Application Identifier (e.g., com.yourorg.bitling), select the provisioning profile, and code signing certificate.
5. Export the project to an Xcode project folder.
6. Open the generated Xcode workspace/project in Xcode.
7. Set the signing team and provisioning profiles if needed (Xcode may auto-manage signing).
8. Build & run on your device. If using a physical device, connect it and select the device as the run target.

Notes
- For automated render/capture, consider creating a dedicated export configuration with fixed window size, disabled VSync and fixed FPS in Project Settings.
- iOS requires the app to request permissions for file sharing if you want the app to write to areas accessible via Files app. Using user:// (app sandbox) is recommended.
