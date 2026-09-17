/// # DisplayControlCore
///
/// A Swift library for programmatic display resolution, refresh rate management, and multi-monitor mirroring configuration on macOS.
///
/// ## Overview
///
/// `DisplayControlCore` integrates and modernizes two open-source macOS display utilities into a safe, concurrency-checked Swift framework:
/// - **Resolution and refresh rate control**: Based on `displaymode` by Dean Scarff (Apache 2.0).
/// - **Display mirroring and topology control**: Based on `mirror-displays` by Fabián Cañas (GPL-3.0).
///
/// The framework provides:
/// - **Display Enumeration**: Comprehensive query of all online displays via CoreGraphics (`CGGetOnlineDisplayList`), including secondary mirror slaves.
/// - **Resolution Switching**: Validation and application of display modes, automatically selecting optimal refresh rates when unspecified.
/// - **Mirroring Topologies**: Support for global mirroring, unmirroring, and selective display-to-display mirroring linkages (`mirror link`).
/// - **Persistent Configuration Profiles**: Profile snapshot capture, JSON serialization, and hardware-backed display restoration by serial number and logical index.
///
/// ## Topics
///
/// ### Articles
///
/// - <doc:Introduction>
/// - <doc:ManagingDisplayConfigurations>
///
/// ### Display Management
///
/// - ``DisplayManager``
/// - ``DisplayInfo``
/// - ``DisplayMode``
/// - ``DisplayError``
///
/// ### Configuration Profiles
///
/// - ``ConfigurationManager``
/// - ``DisplayConfiguration``
/// - ``ConfigurationError``
