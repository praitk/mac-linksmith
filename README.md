# Linksmith

Linksmith is a native macOS utility for creating and managing symbolic links directly from Finder.

The project aims to provide a small, transparent, and trustworthy implementation built entirely with Apple's native technologies.

> [!NOTE]
> Linksmith is currently under development and is not yet ready for general use.

## Goals

Linksmith is designed around a few principles:

- **Native macOS integration** — built with Swift and Apple's macOS frameworks.
- **Local operation** — filesystem operations happen entirely on the Mac.
- **Minimal attack surface** — no network communication, telemetry, background services, or unnecessary dependencies.
- **Auditable implementation** — security-sensitive filesystem operations should remain small and easy to understand.
- **Safe filesystem operations** — potentially destructive operations must validate their inputs and handle failures conservatively.

## Planned functionality

The initial version will focus on symbolic links:

- Create a symbolic link from Finder.
- Copy an item as a symbolic-link source and create the link in another Finder location.
- Support files and directories.
- Support relative and absolute symbolic links.
- Handle naming conflicts safely.

Additional filesystem operations may be considered later.

## Architecture

Linksmith is a native macOS application composed of a small host application and Finder integration.

```text
Finder
  │
  ▼
Linksmith Finder Extension
  │
  ▼
Linksmith filesystem logic
  │
  ▼
Foundation / macOS filesystem
```

Filesystem operations should remain independent from Finder-specific integration wherever practical, allowing the core behavior to be tested separately.

## Technology

- macOS
- Swift
- SwiftUI
- Finder Sync
- Swift Testing
- Xcode

The project aims to avoid third-party runtime dependencies.

## Security

Linksmith handles filesystem paths and operations, so security and predictable behavior are first-class design requirements.

The project should not require:

- network access
- telemetry or analytics
- shell command execution
- root privileges
- background services
- third-party runtime libraries

Potentially destructive functionality should only be introduced with appropriate validation, tests, and failure handling.

## Development

### Requirements

- macOS
- Xcode 26 or later
- Swift 6

Clone the repository and open the Xcode project:

```bash
git clone <repository-url>
cd mac-linksmith
open Linksmith.xcodeproj
```

To build from the command line:

```bash
xcodebuild \
  -project Linksmith.xcodeproj \
  -scheme Linksmith \
  -configuration Debug \
  build
```

## Project status

Linksmith is in early development.

The initial work is focused on establishing the macOS application, Finder integration, filesystem abstraction, and automated tests before implementing the complete symbolic-link workflow.

## License

Linksmith is available under the [MIT License](LICENSE).
