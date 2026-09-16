# DisplayControl

A modern macOS Swift package for managing display mirroring and resolution settings. Combines and modernizes two excellent utilities into a unified tool with CLI, Control Center widgets, and Shortcuts support.

## Features

- **Display Mirroring Control**: Toggle, enable, or disable display mirroring
- **Resolution Management**: Set display resolution and refresh rate for any connected display
- **Named Configurations**: Save and apply named display configurations (e.g., "ipad", "presentation", "extended")
- **Command-Line Interface**: Full-featured CLI tool for automation and scripting
- **Control Center Widget**: Quick access to mirroring controls from macOS Control Center
- **Shortcuts Integration**: Use with Apple Shortcuts for advanced automation

## Based On

This project combines and modernizes two existing open-source utilities:

- **[displaymode](https://github.com/p00ya/displaymode)** by Dean Scarff (Apache 2.0)
  For resolution and refresh rate management

- **[mirror-displays](https://github.com/fcanas/mirror-displays)** by Fabián Cañas (GPL-3.0)
  For display mirroring control

## Requirements

- macOS 14.0 or later
- Swift 5.9 or later
- Xcode 15.0 or later (for building)

## Installation

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/displayctrl.git
cd DisplayControl

# Build the package
swift build -c release

# Install the CLI tool (optional)
cp .build/release/displayctrl /usr/local/bin/
```

### Using Xcode

1. Open `Package.swift` in Xcode
2. Build the project (⌘+B)
3. The CLI tool will be in `.build/release/displayctrl`

## Usage

### Command-Line Interface

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

### Named Configurations

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

### Control Center Widget

1. Build the widget target in Xcode
2. Add the widget to Control Center through System Settings
3. Use the toggle to quickly enable/disable mirroring
4. Access saved configurations with a single click

### Shortcuts Integration

Available intents for use in Apple Shortcuts:

- **Toggle Display Mirroring**: Toggle mirroring on/off
- **Enable Display Mirroring**: Turn mirroring on
- **Disable Display Mirroring**: Turn mirroring off
- **Apply Display Configuration**: Apply a named configuration
- **List Display Configurations**: Get list of saved configurations
- **Set Display Resolution**: Set resolution for a specific display

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

## Development

### Project Structure

```
DisplayControl/
├── Package.swift                           # Swift package manifest
├── Sources/
│   ├── DisplayControl/                     # CLI executable
│   │   └── main.swift
│   ├── DisplayControlCore/                 # Core library
│   │   ├── DisplayInfo.swift              # Data types
│   │   ├── DisplayManager.swift           # Display operations
│   │   └── Configuration.swift            # Config management
│   ├── DisplayControlWidget/              # Control Center widget
│   │   └── DisplayControlWidget.swift
│   └── DisplayControlIntents/             # Shortcuts intents
│       └── DisplayControlIntents.swift
└── Tests/
    └── DisplayControlTests/               # Unit tests
```

### Running Tests

```bash
swift test
```

### Building for Release

```bash
swift build -c release --arch arm64 --arch x86_64
```

## License

This project is licensed under the GNU General Public License v3.0 or later (GPL-3.0-or-later).

This is due to incorporating code from [mirror-displays](https://github.com/fcanas/mirror-displays) which is licensed under GPL-3.0. The GPL license requires derivative works to be distributed under the same license.

### Component Licenses

- Core mirroring functionality: Based on mirror-displays (GPL-3.0)
- Core resolution functionality: Based on displaymode (Apache 2.0)
- Swift integration, UI, and modern features: Original work (GPL-3.0-or-later)

See [LICENSE](LICENSE) for full license text.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- **Dean Scarff** for [displaymode](https://github.com/p00ya/displaymode)
- **Fabián Cañas** for [mirror-displays](https://github.com/fcanas/mirror-displays)

Both projects provided excellent foundational code that made this unified tool possible.

## Troubleshooting

### "No displays detected"
Make sure you have at least one display connected. Some operations (like mirroring) require at least two displays.

### "Mode not found"
The requested resolution may not be supported by your display. Use `displayctrl list` to see available modes.

### Permission Issues
The tool requires permission to change display settings. You may need to grant permissions in System Settings > Privacy & Security.

### Configuration Not Applying
If a saved configuration doesn't work after hardware changes, you may need to recreate it with the new display setup.

## Future Enhancements

- [ ] GUI application
- [ ] Menu bar extra for quick access
- [ ] Display arrangement configuration
- [ ] Color profile management
- [ ] HDR mode control
- [ ] Automated switching based on connected displays

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/yourusername/DisplayControl).
