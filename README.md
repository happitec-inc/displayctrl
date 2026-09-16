# displayctrl

A macOS CLI for managing display mirroring and resolution settings. Combines and modernizes two excellent open-source utilities into a unified tool.

## Features

- **Display Mirroring Control**: Toggle, enable, or disable display mirroring
- **Resolution Management**: Set display resolution and refresh rate for any connected display
- **Named Configurations**: Save and apply named display configurations (e.g., `ipad`, `presentation`, `extended`)
- **Command-Line Interface**: Full-featured CLI for automation and scripting

## Based On

- **[displaymode](https://github.com/p00ya/displaymode)** by Dean Scarff (Apache 2.0) — resolution and refresh rate management
- **[mirror-displays](https://github.com/fcanas/mirror-displays)** by Fabián Cañas (GPL-3.0) — display mirroring control

## Requirements

- macOS 14.0 or later
- Swift 5.9 or later (for building from source)

## Installation

### Homebrew (internal tap)

```bash
brew install happitec-inc/internal/displayctrl
```

### Building from Source

```bash
git clone git@github.com:happitec-inc/displayctrl.git
cd displayctrl

swift build -c release
cp .build/release/displayctrl /usr/local/bin/
```

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

# Create sample configuration file
displayctrl config init

# Show configuration file path
displayctrl config path
```

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
├── Package.swift                       # Swift package manifest
└── Sources/
    ├── DisplayControl/                 # CLI executable (displayctrl)
    │   └── main.swift
    └── DisplayControlCore/             # Core library
        ├── DisplayInfo.swift           # Data types
        ├── DisplayManager.swift        # Display operations
        └── Configuration.swift        # Config management
```

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
