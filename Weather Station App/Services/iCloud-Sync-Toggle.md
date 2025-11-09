# iCloud Sync Toggle Feature

## Overview

Users can now **enable or disable iCloud syncing** for API Configuration Keys via a simple toggle in Settings.

## What Changed

### 1. **APICredentialsSync.swift**

Added:
- `@Published var isSyncEnabled: Bool` - User-controllable preference
- `.disabled` case to `SyncStatus` enum
- Automatic enable/disable logic in `didSet` observer
- Sync state is persisted in UserDefaults (`"iCloudSyncEnabled"`)
- Defaults to **enabled** on first launch

### 2. **SettingsView.swift**

Added:
- Toggle checkbox: "Enable iCloud Sync"
- Dynamic info banner that changes based on sync state:
  - **Enabled**: "API keys automatically sync across your devices via iCloud"
  - **Disabled**: "Credentials are stored locally only"
- Sync status indicator shows "Disabled" when turned off
- Force sync button only appears when sync is enabled

## User Experience

### When iCloud Sync is ENABLED (Default)

```
✅ Enable iCloud Sync

ℹ️ API keys automatically sync across your devices via iCloud

[Application Key field]
[API Key field]

Status: ☁️ Synced (2m ago) ⟳
```

**Behavior:**
- Credentials save to both local storage AND iCloud
- Changes sync across all devices automatically
- Can manually force sync with ⟳ button
- Status shows sync state in real-time

### When iCloud Sync is DISABLED

```
☐ Enable iCloud Sync

ℹ️ Credentials are stored locally only

[Application Key field]
[API Key field]

Status: ☁️ Disabled
```

**Behavior:**
- Credentials save to local storage ONLY
- No cloud uploads or downloads
- Changes do NOT sync to other devices
- Force sync button is hidden (not applicable)
- Existing credentials remain on device

## Technical Details

### Toggle Behavior

**Enabling Sync:**
```swift
credentialsSync.isSyncEnabled = true
```
1. Sets up iCloud observer
2. Performs initial sync (downloads if cloud is newer)
3. Updates status to show sync state
4. Future saves will sync to iCloud

**Disabling Sync:**
```swift
credentialsSync.isSyncEnabled = false
```
1. Removes iCloud observer
2. Updates status to "Disabled"
3. Clears last sync date
4. Future saves are local-only
5. **Does NOT delete existing cloud data**

### Data Persistence

**User Preference:**
```swift
UserDefaults.standard.set(isSyncEnabled, forKey: "iCloudSyncEnabled")
```

**Default Value:**
- First launch: `true` (sync enabled by default)
- Persisted across app launches

### API Methods

**Save Credentials:**
```swift
func saveCredentials(_ credentials: APICredentials)
```
- Always saves locally
- Only saves to iCloud if `isSyncEnabled == true`
- Updates status accordingly

**Load Credentials:**
```swift
func loadCredentials() -> APICredentials
```
- If sync disabled: returns local credentials only
- If sync enabled: returns newer of local or cloud

**Force Sync:**
```swift
func forceSynchronize()
```
- Only works if `isSyncEnabled == true`
- Shows message in console if disabled

## Use Cases

### Why Disable Sync?

1. **Privacy Concerns**: User wants credentials local-only
2. **Multiple Accounts**: Different credentials per device
3. **Testing**: Want separate credentials for development
4. **No iCloud**: User doesn't have/want iCloud enabled
5. **Temporary Disconnect**: Testing without cloud interference

### When to Keep Enabled?

1. **Multiple Devices**: Same credentials across Macs
2. **Convenience**: Set up once, works everywhere
3. **Backup**: Automatic cloud backup of credentials
4. **Default Use Case**: Most users benefit from sync

## Migration & Compatibility

### Existing Users

Users who already have iCloud sync from before will:
- Continue with sync **enabled** by default
- Can toggle off if desired
- Existing credentials remain unchanged

### New Users

New users will:
- Start with sync **enabled** by default
- Can disable before entering credentials if desired
- Get the full benefit of cross-device sync

### Upgrading from Non-Sync Version

Users upgrading from local-only storage will:
- Automatically get sync **enabled**
- Local credentials will upload to iCloud on first save
- Can disable if they prefer local-only

## UI States

### Status Indicator States

| State | Icon | Text | Color | Action Button |
|-------|------|------|-------|---------------|
| Disabled | `icloud.slash` | "Disabled" | Gray | Hidden |
| Idle | `icloud` | "iCloud" | Gray | Visible |
| Syncing | Spinner | "Syncing..." | Gray | Visible |
| Success | `icloud.fill` | "Just now" | Green | Visible |
| Error | `icloud.slash` | "Error" | Red | Visible |

### Toggle Checkbox

```swift
Toggle("Enable iCloud Sync", isOn: $credentialsSync.isSyncEnabled)
    .toggleStyle(.checkbox)
```

- **Checked** = Sync enabled
- **Unchecked** = Sync disabled
- Instantly updates when changed
- Preference persisted immediately

## Code Flow

### Disabling Sync

```
User unchecks toggle
    ↓
credentialsSync.isSyncEnabled = false
    ↓
didSet observer fires
    ↓
disableSync() called
    ↓
- Remove iCloud observer
- Update status to .disabled
- Clear last sync date
    ↓
UI updates automatically (@Published)
```

### Enabling Sync

```
User checks toggle
    ↓
credentialsSync.isSyncEnabled = true
    ↓
didSet observer fires
    ↓
setupCloudObserver() called
performInitialSync() called
    ↓
- Add iCloud observer
- Compare local vs cloud
- Download if cloud newer
- Update status
    ↓
UI updates automatically (@Published)
```

## Important Notes

### What Happens to Cloud Data When Disabled?

- **Cloud data is NOT deleted**
- Existing credentials remain in iCloud
- If re-enabled, sync will resume
- Cloud data can still update from other devices

### Can I Delete Cloud Data?

To manually delete cloud credentials:
```swift
// Not implemented by default, but you could add:
func clearCloudCredentials() {
    cloudStore.removeObject(forKey: CloudKey.applicationKey)
    cloudStore.removeObject(forKey: CloudKey.apiKey)
    cloudStore.removeObject(forKey: CloudKey.lastModified)
    cloudStore.synchronize()
}
```

### What If I Toggle Multiple Times?

- Toggle is immediate and reversible
- No data loss occurs
- Local credentials always preserved
- Cloud credentials remain unless explicitly deleted

## Testing

### Test Scenarios

1. **Toggle Off → Save → Toggle On**
   - Verify local credentials persist
   - Verify sync resumes when re-enabled

2. **Toggle Off → Quit → Relaunch**
   - Verify preference persists
   - Verify stays disabled after relaunch

3. **Disable on Device 1, Change on Device 2**
   - Device 1: Doesn't receive updates (expected)
   - Device 2: Still syncs (independent)

4. **Toggle Off → Toggle On → Check Status**
   - Should show current sync status
   - Should perform initial sync check

## Best Practices

### For Users

1. **Default: Keep Enabled** - Most users benefit from sync
2. **Disable for Privacy** - If you want local-only storage
3. **Test Before Disabling** - Make sure you have credentials saved
4. **Re-enable Anytime** - Toggle is always available

### For Developers

1. **Always save locally** - Even when sync disabled
2. **Check `isSyncEnabled`** - Before cloud operations
3. **Update UI accordingly** - Show appropriate messages
4. **Don't delete cloud data** - When disabling sync

## Summary

✅ **Added user control** over iCloud sync  
✅ **Defaults to enabled** for convenience  
✅ **Preserves local data** always  
✅ **Reversible at any time**  
✅ **Clear visual feedback** in UI  
✅ **No breaking changes** for existing users  

Users now have **full control** over whether their API credentials sync via iCloud!

---

**Last Updated**: November 9, 2025  
**Version**: 1.1  
**Feature**: iCloud Sync Toggle
