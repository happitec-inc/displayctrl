Create a macos swift package with a cli target that combines these two libraries:
- https://github.com/fcanas/mirror-displays
- https://github.com/p00ya/displaymode

Both libraries work well, but neither is modern. This project should:
- Allow toggling of mirroring
- Allow setting of one or both screen resolutions
- Allow for a config file with named configurations (e.g. "ipad" means "make sure the display is mirrored and set to 1600x1200@60hz)

This package should build a cli, and a control center widget, and AppIntent bindings for Shortcuts usage.
- https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system
