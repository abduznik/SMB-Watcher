## Support This Project

> **All projects made with passion** 💙

[![Sponsor me](https://img.shields.io/badge/❤️%20Sponsor-GitHub-red?style=for-the-badge)](https://github.com/sponsors/abduznik)

# SMBWatcher

A macOS menu bar app that watches SMB network shares and automatically remounts them when they drop.

## Features

- **Menu bar app** — lives in the status bar next to WiFi/battery (no Dock icon)
- **Two-stage health checks** — verifies both port reachability AND mount liveness
- **Auto-remount** — automatically remounts dropped shares without user intervention
- **Exponential backoff** — avoids hammering offline servers with repeated mount attempts
- **Keychain integration** — stores SMB credentials securely in macOS Keychain
- **User notifications** — alerts you when mounts fail after exhausting retries

## Requirements

- macOS 13.0+
- Swift 5.9+
- Xcode 15.0+

## Building

1. Clone the repository:
   ```bash
   git clone https://github.com/abduznik/SMB-Watcher.git
   cd SMB-Watcher
   ```

2. Open the Xcode project:
   ```bash
   open SMBWatcher/SMBWatcher.xcodeproj
   ```

3. Select your development team in Signing & Capabilities.

4. Build and run (⌘R).

## Usage

1. After launching, SMBWatcher appears in the menu bar (look for the drive icon).

2. Click the icon and select **"Add Instance…"** to configure your first SMB share:
   - **Name**: A friendly label (e.g., "Homelab NAS")
   - **Host**: The server's IP or hostname
   - **Port**: Usually 445
   - **Share Path**: The path on the server (e.g., `/volume1/media`)
   - **Mount Point**: Where to mount locally (e.g., `/Volumes/media`)
   - **Username/Password**: Your SMB credentials (stored in Keychain)

3. Click **Save** — SMBWatcher will begin monitoring the share.

4. The menu bar icon changes color based on status:
   - ✓ Green: All shares healthy
   - ⚠ Yellow: One or more shares unreachable
   - ✗ Red: One or more shares failed after retries

## How It Works

### Health Checks

SMBWatcher performs two-stage health checks:

1. **Port Reachability**: TCP connection test to verify the server is network-reachable.
2. **Mount Liveness**: Directory listing test to verify the mount is actually responsive (not just present in `/Volumes`).

### Backoff Strategy

When a share becomes unreachable:
- Initial retry interval matches the configured poll interval (default 30s)
- Each failed attempt doubles the interval (exponential backoff)
- Maximum interval is 10 minutes
- Resets to base interval after a successful health check

### Stale Mount Cleanup

Before remounting, SMBWatcher detects and cleans up "zombie" mounts — mounts that appear in `/Volumes` but are unresponsive. This prevents duplicate mount points (e.g., `Media-1`, `Media-2`).

## Configuration

Instances are stored in:
```
~/Library/Application Support/SMBWatcher/instances.json
```

Credentials are stored in macOS Keychain under the service `com.smbwatcher.credentials`.

## Architecture

```
SMBWatcher/
├── Models/
│   ├── WatchedInstance.swift    # Data model for watched shares
│   └── InstanceStatus.swift    # Health status enum
├── Services/
│   ├── ConfigStore.swift       # JSON config persistence
│   ├── KeychainService.swift   # Credential management
│   ├── PortReachability.swift  # TCP connectivity checks
│   ├── MountHealthChecker.swift # Two-stage health verification
│   ├── MountManager.swift      # Mount/unmount operations
│   └── WatcherEngine.swift     # Background monitoring orchestration
└── UI/
    ├── StatusBarController.swift # Menu bar management
    └── AddInstanceView.swift    # SwiftUI add/edit form
```

## Non-Goals (v1)

- No launchd agent (app manages its own timers)
- No iCloud sync
- No Windows/Linux support
- No NFS/AFP support

## License

MIT License - see [LICENSE](LICENSE) for details.
