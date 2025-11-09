# iCloud Syncing Setup Guide

## Overview

Your Weather Station app now supports automatic iCloud syncing for API Configuration Keys. This means your Ecowitt API credentials will automatically sync across all your Mac devices signed in to the same iCloud account.

## What Gets Synced

**Only the following data is synced via iCloud:**
- Application Key (Ecowitt)
- API Key (Ecowitt)

**NOT synced (remains local to each device):**
- Weather stations list
- Historical weather data
- App preferences and settings
- Menu bar configuration

## Requirements

1. **macOS Version**: Your app must be running on macOS with iCloud Key-Value Store support
2. **iCloud Account**: You must be signed in to iCloud on all devices
3. **Network Connection**: Internet connectivity required for syncing
4. **Xcode Capabilities**: The iCloud capability must be enabled in your Xcode project

## Xcode Project Setup

To enable iCloud syncing, you need to add the iCloud capability to your project:

### Step 1: Enable iCloud Capability

1. Open your project in Xcode
2. Select your app target
3. Go to the "Signing & Capabilities" tab
4. Click "+ Capability" button
5. Add "iCloud"
6. Under Services, check "Key-value storage"

### Step 2: Configure Entitlements

The following entitlement will be automatically added to your app:

```xml
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
```

### Step 3: Info.plist (Optional)

No additional Info.plist entries are required for Key-Value Store.

## How It Works

### Automatic Syncing

- **When you save**: Credentials are immediately saved to both local storage and iCloud
- **When you launch**: The app checks for the newest version between local and iCloud
- **When changes arrive**: If credentials change on another device, your app updates automatically

### Conflict Resolution

The app uses a "last-write-wins" strategy:
- Each credential save includes a timestamp
- When syncing, the most recent version is always used
- No data is lost - the newest update always takes precedence

### Sync Status Indicators

In the Settings view, you'll see a sync status indicator next to "API Configuration":

- **iCloud (gray)**: Idle, ready to sync
- **Syncing... (animated)**: Currently syncing with iCloud
- **iCloud ✓ (green)**: Successfully synced (shows time since last sync)
- **iCloud ⚠ (red)**: Sync error (hover for details)

You can also manually force a sync by clicking the refresh button (⟳) next to the status.

## Testing iCloud Sync

### Test on Multiple Devices

1. **Device 1**: Launch the app and enter your API credentials
2. **Device 2**: Launch the app (or if already running, wait a few seconds)
3. **Device 2**: The credentials should automatically appear
4. **Verify**: Check the sync status indicator shows "Synced"

### Test Conflict Resolution

1. **Both Devices**: Disconnect from internet
2. **Device 1**: Change credentials to "Test1"
3. **Device 2**: Change credentials to "Test2"
4. **Both Devices**: Reconnect to internet
5. **Result**: Both devices will show whichever change was made most recently

## Troubleshooting

### Sync Not Working

1. **Check iCloud Status**
   - Go to System Settings > Apple ID
   - Ensure you're signed in to iCloud
   - Verify iCloud Drive is enabled

2. **Check Network Connection**
   - iCloud requires an active internet connection
   - Firewall settings may block iCloud sync

3. **Force Sync**
   - Click the refresh button (⟳) next to sync status
   - This manually triggers synchronization

4. **Check Storage Quota**
   - iCloud Key-Value Store has a 1MB limit per app
   - API credentials are extremely small (~100 bytes)
   - You should never hit this limit

### Credentials Not Appearing on New Device

1. **Wait**: Initial sync can take up to 60 seconds
2. **Force Sync**: Click the refresh button
3. **Relaunch**: Quit and reopen the app
4. **Check iCloud**: Ensure the same Apple ID is signed in on both devices

### Different Credentials on Different Devices

1. This means both devices had the credentials changed while offline
2. The most recent change will eventually propagate to all devices
3. To resolve: Choose one device as the "source of truth" and re-save the credentials

## Privacy & Security

### Data Security

- **Encryption**: All iCloud data is encrypted in transit and at rest
- **Secure Storage**: Credentials are stored in iCloud's secure key-value store
- **No Third Party**: Data only syncs between your own devices via Apple's iCloud
- **Local Fallback**: If iCloud is unavailable, local storage is used

### What Apple Can See

- Apple can see that your app stores data in iCloud
- Apple cannot see the actual API credentials (they're encrypted)
- Apple does not share or sell your iCloud data

## Best Practices

1. **Use Same Apple ID**: Ensure all devices use the same iCloud account
2. **Stay Connected**: Keep devices connected to the internet for real-time sync
3. **Monitor Status**: Check the sync status indicator occasionally
4. **Don't Disable iCloud**: Keep iCloud enabled in System Settings

## Technical Details

### Storage Used

- **Application Key**: ~40-100 characters
- **API Key**: ~40-100 characters  
- **Metadata**: ~50 bytes (timestamps)
- **Total**: Less than 500 bytes per user

### Sync Timing

- **Upload**: Immediate when credentials are saved
- **Download**: Within seconds when changed on another device
- **Initial Sync**: On app launch, typically < 1 second
- **Network**: Uses minimal bandwidth (<1 KB per sync)

### API Used

The app uses `NSUbiquitousKeyValueStore`, Apple's recommended solution for syncing small amounts of key-value data:

- **Designed for**: App preferences, settings, credentials
- **Limits**: 1 MB total, 1024 keys max
- **Reliability**: Automatic, handled by the system
- **Platforms**: Available on macOS, iOS, iPadOS, watchOS, tvOS

## Limitations

1. **macOS Only**: This implementation is for macOS only
   - To extend to iOS/iPadOS, use the same `APICredentialsSync` class
   
2. **Small Data Only**: iCloud Key-Value Store is not for large data
   - Perfect for API credentials
   - Not suitable for weather data or history

3. **Requires iCloud**: Users must have an iCloud account
   - App still works without iCloud
   - Credentials are stored locally as a fallback

## Future Enhancements

Possible improvements for future versions:

1. **Sync Weather Stations**: Optionally sync station list via CloudKit
2. **Cross-Platform**: Extend to iOS/iPadOS companion app
3. **Manual Override**: Allow users to disable sync if desired
4. **Import/Export**: Backup and restore credentials manually
5. **Multi-Account**: Support multiple credential sets

## Support

If you experience issues with iCloud syncing:

1. Check this documentation first
2. Verify your Xcode project capabilities are correct
3. Test with a simple sync (add, wait, check other device)
4. Check Console.app for sync-related logs (filter for "APICredentialsSync")

---

Last updated: November 9, 2025
