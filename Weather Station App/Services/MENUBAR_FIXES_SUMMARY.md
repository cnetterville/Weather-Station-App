# Menu Bar Fixes Summary

## Issues Fixed

### 1. ✅ Last Updated Times in Menu Bar Context Menu

**Problem:** The right-click context menu didn't show when each station was last updated.

**Solution:** Enhanced the `showContextMenu()` method to dynamically build the menu with current data, including:
- Last updated timestamp for each station
- Time ago format (e.g., "5 minutes ago")
- Actual time (e.g., "2:35 PM")
- Different displays based on mode:
  - **Single Station Mode:** Shows the selected station's update time
  - **All Stations Mode:** Shows all active stations with their update times
  - **Cycle Through Mode:** Shows current station first (with → indicator), then all others

**Example Menu Display:**
```
Open Weather Station App
------------------------
Last Updated:
  → Home Station: 2 minutes ago (2:35 PM)
    Office Station: 5 minutes ago (2:32 PM)
    Garage Station: 3 minutes ago (2:34 PM)
------------------------
Refresh Data
------------------------
Quit Weather Station App
```

### 2. ✅ Background Refresh Timer Reliability

**Problem:** The menu bar data stopped updating after a while when the main window was closed. This was caused by using `Timer.scheduledTimer()`, which is unreliable in background scenarios and can be paused by the system.

**Solution:** Replaced `Timer` with `DispatchSourceTimer` for the background refresh mechanism.

**Key Changes:**
- Changed `backgroundRefreshTimer` from `Timer?` to `DispatchSourceTimer?`
- Implemented timer using `DispatchSource.makeTimerSource()` with a background queue
- Added leeway of 5 seconds for system power optimization
- Timer runs on a dedicated background queue (`com.weatherstation.menubar.refresh`)
- Uses QoS (Quality of Service) `.utility` for appropriate system resource allocation

**Benefits of DispatchSourceTimer:**
1. **More Reliable:** Continues firing even when app is in background
2. **Better Performance:** Runs on background queue, doesn't block main thread
3. **System-Friendly:** Leeway parameter allows system to coalesce events for battery efficiency
4. **Survives App State Changes:** More resilient to app lifecycle events

**Technical Details:**
```swift
// Old approach (unreliable in background)
backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { ... }

// New approach (reliable in background)
let queue = DispatchQueue(label: "com.weatherstation.menubar.refresh", qos: .utility)
let timer = DispatchSource.makeTimerSource(queue: queue)
timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .seconds(5))
timer.setEventHandler { ... }
timer.resume()
```

## Testing Recommendations

1. **Test Last Updated Display:**
   - Right-click the menu bar icon
   - Verify you see "Last Updated:" section with timestamps
   - Try all three display modes (Single, All Stations, Cycle Through)
   - Verify the "time ago" format updates correctly

2. **Test Background Refresh:**
   - Close all main windows (keep only menu bar active)
   - Wait for the refresh interval (default: 10 minutes)
   - Verify data updates in the menu bar
   - Check Console logs for "MenuBar background refresh timer fired" messages
   - Leave running overnight to verify long-term reliability

3. **Test Edge Cases:**
   - Close and reopen main window while menu bar is active
   - Verify refresh switches between main app and menu bar correctly
   - Check that dock icon hiding still works
   - Verify tooltip shows correct data

## Additional Notes

- The timer uses a 5-second leeway, which means it might fire up to 5 seconds later than the exact interval. This is intentional for battery efficiency and is acceptable for weather data updates.
- The background refresh only runs when the main app window is hidden and the menu bar is enabled.
- When the main app becomes visible, the menu bar stops its background refresh (AppStateManager handles the main refresh).
- The implementation includes extensive logging for debugging timer behavior. Look for `logRefresh()` messages in the Console.

## Files Modified

1. **MenuBarManager.swift**
   - Changed `backgroundRefreshTimer` from `Timer?` to `DispatchSourceTimer?`
   - Rewrote `startBackgroundRefresh()` to use DispatchSourceTimer
   - Updated `stopBackgroundRefresh()` to properly cancel DispatchSourceTimer
   - Enhanced `showContextMenu()` to include last updated information
   - Simplified `setupContextMenu()` since menu is now built dynamically
   - Added `addLastUpdatedInfo()` helper method for consistent formatting

## No Breaking Changes

These changes are fully backward compatible and don't affect:
- User preferences
- Saved data
- Other parts of the app
- API interactions
