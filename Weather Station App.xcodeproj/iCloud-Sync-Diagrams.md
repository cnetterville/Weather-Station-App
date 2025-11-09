# iCloud Sync Flow Diagrams

## Basic Sync Flow

```
┌─────────────────────────────────────────────────────────────┐
│                         User Action                         │
│           "Saves API Keys in Settings View"                 │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   WeatherStationService                     │
│            updateCredentials(appKey, apiKey)                │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  APICredentialsSync.shared                  │
│                  saveCredentials(credentials)               │
└────────────┬──────────────────────────────┬─────────────────┘
             │                              │
             ▼                              ▼
┌────────────────────────┐    ┌──────────────────────────────┐
│    Local Storage       │    │    iCloud Storage            │
│    (UserDefaults)      │    │  (NSUbiquitousKVStore)       │
│                        │    │                              │
│  • Application Key     │    │  • Application Key           │
│  • API Key             │    │  • API Key                   │
│  • Timestamp           │    │  • Timestamp                 │
└────────────────────────┘    └──────────────┬───────────────┘
                                              │
                                              │ Syncs via iCloud
                                              │
                                              ▼
                              ┌──────────────────────────────┐
                              │     Other Mac Devices        │
                              │  (Same Apple ID/iCloud)      │
                              └──────────────┬───────────────┘
                                             │
                                             ▼
                              ┌──────────────────────────────┐
                              │  Notification Received       │
                              │  didChangeExternally         │
                              └──────────────┬───────────────┘
                                             │
                                             ▼
                              ┌──────────────────────────────┐
                              │  APICredentialsSync          │
                              │  handleCloudStoreChange()    │
                              └──────────────┬───────────────┘
                                             │
                                             ▼
                              ┌──────────────────────────────┐
                              │  Update Local Storage        │
                              │  Post Notification           │
                              └──────────────┬───────────────┘
                                             │
                                             ▼
                              ┌──────────────────────────────┐
                              │  WeatherStationService       │
                              │  Receives Notification       │
                              │  Updates credentials         │
                              └──────────────┬───────────────┘
                                             │
                                             ▼
                              ┌──────────────────────────────┐
                              │  UI Updates Automatically    │
                              │  (via @Published)            │
                              └──────────────────────────────┘
```

## App Launch Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      App Launches                           │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│            WeatherStationService.init()                     │
│                 loadCredentials()                           │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│           APICredentialsSync.loadCredentials()              │
└────────────┬──────────────────────────────┬─────────────────┘
             │                              │
             ▼                              ▼
┌────────────────────────┐    ┌──────────────────────────────┐
│  Load from Local       │    │  Load from iCloud            │
│  (UserDefaults)        │    │  (NSUbiquitousKVStore)       │
│                        │    │                              │
│  Timestamp: T1         │    │  Timestamp: T2               │
└────────────┬───────────┘    └──────────────┬───────────────┘
             │                               │
             └───────────┬───────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                Compare Timestamps                           │
│                                                             │
│  IF T2 > T1:  Use iCloud version (cloud is newer)          │
│  IF T1 > T2:  Use Local version (local is newer)           │
│  IF T1 == T2: Already in sync                              │
│  IF T1 exists but not T2: Upload to cloud                  │
│  IF T2 exists but not T1: Download from cloud              │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Return Newest Credentials                      │
│           (Automatically sync if needed)                    │
└─────────────────────────────────────────────────────────────┘
```

## Conflict Resolution Flow

```
Scenario: User changes credentials on two devices while offline

Device A (Offline)                    Device B (Offline)
─────────────────                    ─────────────────
Changes creds to "Key-A"             Changes creds to "Key-B"
Timestamp: 10:00:00                  Timestamp: 10:00:05
Saves locally ✓                      Saves locally ✓
Cannot sync to iCloud ✗              Cannot sync to iCloud ✗

        │                                    │
        │ Both devices reconnect             │
        │ to internet                        │
        ▼                                    ▼

┌───────────────────┐              ┌───────────────────┐
│   Device A        │              │   Device B        │
│   Syncs to cloud  │              │   Syncs to cloud  │
│   Uploads Key-A   │              │   Uploads Key-B   │
│   Time: 10:00:00  │              │   Time: 10:00:05  │
└────────┬──────────┘              └──────┬────────────┘
         │                                │
         └────────────┬──────────────────┘
                      ▼
         ┌────────────────────────┐
         │    iCloud Storage      │
         │  Receives both updates │
         │  (Nearly simultaneous) │
         └────────────┬───────────┘
                      ▼
         ┌────────────────────────┐
         │  Compare Timestamps    │
         │  10:00:05 > 10:00:00   │
         │  Key-B wins!           │
         └────────────┬───────────┘
                      │
         ┌────────────┴───────────┐
         ▼                        ▼
┌───────────────────┐    ┌───────────────────┐
│   Device A        │    │   Device B        │
│ Receives update   │    │ Already has       │
│ Changes to Key-B  │    │ Key-B ✓           │
│ Timestamp updated │    │                   │
└───────────────────┘    └───────────────────┘

Result: Both devices converge to "Key-B" (most recent)
```

## Multi-Device Sync Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Mac #1    │    │   Mac #2    │    │   Mac #3    │
│  (Primary)  │    │  (Kitchen)  │    │  (Office)   │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                   │
       │ Saves creds      │                   │
       │ "MyAPIKey"       │                   │
       ▼                  │                   │
   ┌─────────┐            │                   │
   │  Saved  │            │                   │
   │ Locally │            │                   │
   └────┬────┘            │                   │
        │                 │                   │
        │ Uploads         │                   │
        ▼                 │                   │
   ┌──────────────────────────────────────────┐
   │          iCloud Key-Value Store          │
   │         Stores: "MyAPIKey"               │
   └────────────┬──────────────┬──────────────┘
                │              │
                │ Pushes       │ Pushes
                ▼              ▼
       ┌────────────┐    ┌────────────┐
       │  Mac #2    │    │  Mac #3    │
       │  Receives  │    │  Receives  │
       └─────┬──────┘    └─────┬──────┘
             │                 │
             ▼                 ▼
      ┌────────────┐    ┌────────────┐
      │ Downloads  │    │ Downloads  │
      │ "MyAPIKey" │    │ "MyAPIKey" │
      └────────────┘    └────────────┘

Timeline: < 5 seconds from save to all devices updated
```

## Sync Status States

```
┌─────────────────────────────────────────────────────────────┐
│                  Sync Status Indicator                      │
└─────────────────────────────────────────────────────────────┘

State 1: IDLE
┌─────────────────────┐
│  ☁️  iCloud         │  No recent activity
└─────────────────────┘  Ready to sync

State 2: SYNCING
┌─────────────────────┐
│  ⚙️  Syncing...     │  Active sync in progress
└─────────────────────┘  API call in flight

State 3: SUCCESS
┌─────────────────────┐
│  ✅ Synced (2m ago) │  Successfully synced
└─────────────────────┘  Shows relative time

State 4: ERROR
┌─────────────────────┐
│  ⚠️  Sync Error     │  Quota/network issue
└─────────────────────┘  Hover for details

Actions:
┌─────┐
│  ⟳  │  Force sync button (always visible)
└─────┘  Manually trigger synchronization
```

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Presentation Layer                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              SettingsView.swift                      │   │
│  │  • User enters API credentials                       │   │
│  │  • Displays sync status                              │   │
│  │  • Shows last sync time                              │   │
│  │  • Manual sync button                                │   │
│  └───────────────────────┬──────────────────────────────┘   │
└────────────────────────────┼───────────────────────────────┘
                             │ SwiftUI Bindings
                             │ @StateObject
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                        Business Logic                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         WeatherStationService.swift                  │   │
│  │  • Manages credentials lifecycle                     │   │
│  │  • Delegates to sync service                         │   │
│  │  • Observes sync notifications                       │   │
│  │  • Updates UI via @Published                         │   │
│  └───────────────────────┬──────────────────────────────┘   │
└────────────────────────────┼───────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                       Sync Service Layer                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │          APICredentialsSync.swift                    │   │
│  │  • Manages sync state machine                        │   │
│  │  • Handles conflict resolution                       │   │
│  │  • Observes iCloud changes                           │   │
│  │  • Posts notifications                               │   │
│  │  • Coordinates local + cloud storage                 │   │
│  └──────┬──────────────────────────────┬────────────────┘   │
└─────────┼──────────────────────────────┼───────────────────┘
          │                              │
          ▼                              ▼
┌───────────────────┐        ┌─────────────────────────────┐
│  Local Storage    │        │    Cloud Storage            │
│  ─────────────    │        │    ─────────────            │
│  UserDefaults     │        │  NSUbiquitousKeyValueStore  │
│                   │        │                             │
│  • Fast access    │        │  • Automatic sync           │
│  • Offline ready  │        │  • Apple managed            │
│  • Fallback       │        │  • Encrypted                │
└───────────────────┘        └─────────────────────────────┘
```

## Notification Flow

```
┌─────────────────────────────────────────────────────────────┐
│  iCloud sends: didChangeExternallyNotification              │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│            APICredentialsSync observes                      │
│         handleCloudStoreChange() called                     │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ├─→ Check change reason:
                           │   • Server change
                           │   • Initial sync
                           │   • Quota violation
                           │   • Account change
                           │
                           ├─→ Compare timestamps
                           │   • Cloud newer? Update local
                           │   • Local newer? Keep local
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│     Post: .apiCredentialsDidChange notification             │
│     UserInfo: ["credentials": APICredentials]               │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│     WeatherStationService observes notification             │
│     Updates self.credentials @Published property            │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│            SwiftUI automatically re-renders                 │
│     Any view observing weatherService.credentials           │
└─────────────────────────────────────────────────────────────┘
```

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   Error Scenarios                           │
└─────────────────────────────────────────────────────────────┘

1. Quota Exceeded
   ┌──────────────────┐
   │ iCloud quota     │→ didChangeExternallyNotification
   │ exceeded         │  (reason: QuotaViolation)
   └─────┬────────────┘
         ▼
   ┌──────────────────┐
   │ Update status    │
   │ .error("Quota    │
   │  exceeded")      │
   └─────┬────────────┘
         ▼
   ┌──────────────────┐
   │ Show red icon    │
   │ in Settings UI   │
   └──────────────────┘

2. Network Unavailable
   ┌──────────────────┐
   │ No internet      │→ Sync attempt fails silently
   └─────┬────────────┘
         ▼
   ┌──────────────────┐
   │ Use local cache  │
   │ (UserDefaults)   │
   └─────┬────────────┘
         ▼
   ┌──────────────────┐
   │ App continues    │
   │ working offline  │
   └─────┬────────────┘
         ▼
   ┌──────────────────┐
   │ Auto-sync when   │
   │ reconnected      │
   └──────────────────┘

3. iCloud Not Signed In
   ┌──────────────────┐
   │ User not signed  │→ NSUbiquitousKVStore unavailable
   │ in to iCloud     │
   └─────┬────────────┘
         ▼
   ┌──────────────────┐
   │ Fall back to     │
   │ UserDefaults     │
   │ (local only)     │
   └─────┬────────────┘
         ▼
   ┌──────────────────┐
   │ No sync icon     │
   │ shown (idle)     │
   └──────────────────┘

4. Account Changed
   ┌──────────────────┐
   │ User switches    │→ didChangeExternallyNotification
   │ Apple ID         │  (reason: AccountChange)
   └─────┬────────────┘
         ▼
   ┌──────────────────┐
   │ Trigger full     │
   │ re-sync          │
   └─────┬────────────┘
         ▼
   ┌──────────────────┐
   │ Load credentials │
   │ from new account │
   └──────────────────┘
```

---

**Legend:**
- → = Data flow
- ▼ = Sequential step
- ✓ = Success state
- ✗ = Failed state
- ⚙️ = Processing
