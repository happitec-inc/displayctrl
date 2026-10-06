# displayctrl

A macOS tool for managing display mirroring and resolution settings. Combines and modernizes two excellent open-source utilities into a unified CLI, GUI preset manager, menu bar extra, Control Center widget, and Shortcuts integration.

## Features

- **Display Mirroring Control**: Toggle, enable, or disable display mirroring
- **Resolution Management**: Set display resolution and refresh rate for any connected display
- **Named Configurations**: Save and apply named display configurations (e.g., `ipad`, `presentation`, `extended`)
- **Command-Line Interface**: Full-featured CLI for automation and scripting
- **GUI Preset Manager**: Native SwiftUI app for browsing and applying presets
- **Menu Bar Extra**: Companion app with preset access from the menu bar
- **Control Center Widget**: Quick access to mirroring controls from macOS Control Center (macOS 26+)
- **Shortcuts Integration**: AppIntents for use with Apple Shortcuts (macOS 14+)

## Based On

- **[displaymode](https://github.com/p00ya/displaymode)** by Dean Scarff (Apache 2.0) — resolution and refresh rate management
- **[mirror-displays](https://github.com/fcanas/mirror-displays)** by Fabián Cañas (GPL-3.0) — display mirroring control

## Requirements

- macOS 26.0 or later (package minimum; the Control Center widget requires it)
- macOS 14.0 or later (for the Shortcuts intents on their own)
- Swift 6.3 or later (for building from source)

## Installation

### Homebrew

```bash
brew install happitec-inc/tap/displayctrl
```

Or tap first:

```bash
brew tap happitec-inc/tap
brew install displayctrl
```

### Building from Source

```bash
git clone https://github.com/happitec-inc/displayctrl.git
cd displayctrl

swift build -c release
cp .build/release/displayctrl /usr/local/bin/
```

### Building the App Bundle

The `.app` bundle — GUI preset manager plus the embedded Control Center
widget extension — is built with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project DisplayControl.xcodeproj -scheme DisplayControlApp -configuration Release
```

Or open `DisplayControl.xcodeproj` in Xcode and build the `DisplayControlApp`
scheme (run it with ⌘R). Signing and notarization follow the same
`notarize-macos-app.yml` pattern used for agents.happitec.com.

## Usage

```bash
# List all displays and available modes
displayctrl list

# Enable mirroring
displayctrl mirror on

# Disable mirroring
displayctrl mirror off

# Toggle mirroring
displayctrl mirror toggle

# Check mirroring status
displayctrl mirror status

# Make display 1 mirror display 0
displayctrl mirror link 1 0

# Set main display (0) to 1920x1080 at 60Hz
displayctrl resolution set 0 1920 1080 60

# Set secondary display (1) to 2560x1440 (any refresh rate)
displayctrl resolution set 1 2560 1440

# Save current setup as a named configuration
displayctrl config save ipad

# Apply a saved configuration
displayctrl config apply ipad

# List all saved configurations
displayctrl config list

# Show details of a configuration
displayctrl config show ipad

# Delete a configuration
displayctrl config delete ipad

# Create sample configuration file (use --force to overwrite existing)
displayctrl config init
displayctrl config init --force

# Show configuration file path
displayctrl config path
```

## GUI & Menu Bar

Two executables ship from this package:

- **`DisplayControlApp`** — the Preset Manager window (all saved configurations,
  with create/edit/delete/apply), included in the `.app` bundle above.
- **`DisplayControlMenu`** — a `MenuBarExtra` companion living in the menu bar
  with the same preset access. It works as an alternative to, or alongside, the
  Control Center widget; the widget requires macOS 26 while the menu bar extra
  is available since macOS 13.

Build either with SwiftPM (`swift build -c release`) or from the Xcode project.

## Control Center Widget

1. Build and run the `DisplayControlApp` target from `DisplayControl.xcodeproj`
   (this installs the embedded widget extension).
2. Open System Settings > Control Center & Widgets and add:
   - **Display Mirroring** — a toggle that flips mirroring on or off.
   - **Display Configuration** — a picker populated live from your saved
     configurations; pick one and pressing the control applies it.
3. Configuration choices are read from the same
   `displayconfigs.json` the CLI and GUI use, so presets you save elsewhere
   appear in the picker without rebuilding.

The Control Center controls require macOS 26.0 or later.

## Shortcuts Integration

Available intents for use in Apple Shortcuts:

- **Toggle Display Mirroring**: Toggle mirroring on/off
- **Enable Display Mirroring**: Turn mirroring on
- **Disable Display Mirroring**: Turn mirroring off
- **Apply Display Configuration**: Apply a named configuration
- **List Display Configurations**: Get the list of saved configuration names
- **Set Display Resolution**: Set a display's width/height (refresh rate optional)

Suggested phrases (say to Siri or use in Shortcuts): "Toggle display mirroring
in DisplayControl", "Switch to ipad in DisplayControl", and similar variants.

AppIntents work on macOS 14.0 and later, so the `DisplayControlIntents` target
can ship ahead of the widget if needed.

## Named Configurations

Configurations are stored in JSON format at:

```
~/Library/Application Support/DisplayControl/displayconfigs.json
```

Example configuration file:
```json
[
  {
    "name": "ipad",
    "mirroring": "enabled",
    "displays": [
      {
        "index": 0,
        "width": 1600,
        "height": 1200,
        "refreshRate": 60
      }
    ]
  },
  {
    "name": "extended",
    "mirroring": "disabled",
    "displays": [
      {
        "index": 0,
        "width": 2560,
        "height": 1440
      },
      {
        "index": 1,
        "width": 1920,
        "height": 1080
      }
    ]
  }
]
```

## Configuration Examples

### iPad Mirroring Setup
```bash
# Set to a common resolution and enable mirroring
displayctrl resolution set 0 1600 1200 60
displayctrl mirror on
displayctrl config save ipad

# Later, apply it with one command
displayctrl config apply ipad
```

### Presentation Mode
```bash
# Set to 1080p and enable mirroring
displayctrl resolution set 0 1920 1080 60
displayctrl mirror on
displayctrl config save presentation
```

### Extended Desktop
```bash
# Set both displays and disable mirroring
displayctrl resolution set 0 2560 1440
displayctrl resolution set 1 1920 1080
displayctrl mirror off
displayctrl config save extended
```

## Project Structure

```
displayctrl/
├── Package.swift                         # Swift package manifest
├── project.yml                           # XcodeGen spec for the .app bundle
└── Sources/
    ├── DisplayControl/                   # CLI executable (displayctrl)
    │   └── main.swift
    ├── DisplayControlApp/                # Preset Manager GUI (@main SwiftUI app)
    ├── DisplayControlMenu/               # Menu bar extra (MenuBarExtra)
    ├── DisplayControlCore/               # Core library
    │   ├── DisplayInfo.swift             # Data types
    │   ├── DisplayManager.swift          # Display operations
    │   └── Configuration.swift           # Config management
    ├── DisplayControlUI/                 # Views, preset store, window manager
    ├── DisplayControlIntents/            # AppIntents for Shortcuts
    └── DisplayControlWidget/             # Control Center widget (ControlWidgets)
```

`DisplayControl.xcodeproj` is generated, not committed: run
`xcodegen generate` after cloning.

## Building for Release

```bash
swift build -c release --arch arm64
```

## Troubleshooting

### "No displays detected"
Make sure you have at least one display connected. Some operations (like mirroring) require at least two displays.

### "Mode not found"
The requested resolution may not be supported by your display. Use `displayctrl list` to see available modes.

### Permission Issues
The tool requires permission to change display settings. You may need to grant access in System Settings > Privacy & Security.

### Configuration Not Applying
If a saved configuration doesn't work after hardware changes, recreate it with the new display setup.

## Documentation

Full API documentation for `DisplayControlCore` is hosted via GitHub Pages:
- [DisplayControlCore Documentation](https://docs.happitec.com/displayctrl/documentation/displaycontrolcore/)

Topic articles:
- [Introduction to DisplayControl](https://docs.happitec.com/displayctrl/documentation/displaycontrolcore/introduction)
- [Managing Display Configurations](https://docs.happitec.com/displayctrl/documentation/displaycontrolcore/managingdisplayconfigurations)

## License

This project is licensed under the GNU General Public License v3.0 or later (GPL-3.0-or-later), due to incorporating code from [mirror-displays](https://github.com/fcanas/mirror-displays) which is GPL-3.0. The GPL requires derivative works to use the same license.

### Component Licenses

- Core mirroring functionality: Based on mirror-displays (GPL-3.0)
- Core resolution functionality: Based on displaymode (Apache 2.0)
- Swift integration and modernization: Original work (GPL-3.0-or-later)

See [LICENSE](LICENSE) for the full license text.

## Acknowledgments

- **Dean Scarff** for [displaymode](https://github.com/p00ya/displaymode)
- **Fabián Cañas** for [mirror-displays](https://github.com/fcanas/mirror-displays)
