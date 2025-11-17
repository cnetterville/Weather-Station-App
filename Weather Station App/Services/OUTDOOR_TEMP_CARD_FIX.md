# Outdoor Temperature Card - "Tonight's" to "Today's" Transition Fix

## Problem

The Outdoor Temperature card was not properly transitioning from "Tonight's Forecast" back to "Today's Forecast" at midnight. The text would continue to say "Tonight's Forecast" even after midnight passed, when it should change to "Today's Forecast" for the new day.

## Root Cause

The `isNighttime()` function in the Outdoor Temperature Card was using different logic than the ForecastCard:

**Old Logic (Incorrect):**
```swift
// Only checked if it's after sunset (any time before next sunrise)
if let sunTimes = SunCalculator.calculateSunTimes(...) {
    return !sunTimes.isCurrentlyDaylight  // TRUE from sunset to sunrise
}
```

This meant:
- ⏰ 7:00 PM (after sunset): "Tonight's Forecast" ✅ Correct
- ⏰ 11:00 PM: "Tonight's Forecast" ✅ Correct
- ⏰ 12:30 AM (past midnight): "Tonight's Forecast" ❌ **Wrong!** Should be "Today's Forecast"
- ⏰ 6:00 AM (before sunrise): "Tonight's Forecast" ❌ **Wrong!** Should be "Today's Forecast"

**New Logic (Correct):**
```swift
// Check if it's after sunset but BEFORE midnight
let currentDate = Date()
let startOfTomorrow = calendar.startOfDay(for: currentDate) + 1 day

return currentDate >= sunTimes.sunset && currentDate < startOfTomorrow
```

This means:
- ⏰ 7:00 PM (after sunset): "Tonight's Forecast" ✅ Correct
- ⏰ 11:00 PM: "Tonight's Forecast" ✅ Correct
- ⏰ 12:00 AM (midnight): "Today's Forecast" ✅ **Fixed!**
- ⏰ 6:00 AM (before sunrise): "Today's Forecast" ✅ **Fixed!**

## Solution

Updated the `isNighttime()` function in the Outdoor Temperature Card to match the logic already used in the ForecastCard's `RestOfDaySection`. The key change is adding a check for midnight:

```swift
// Get start of next day (midnight)
let startOfTomorrow = localCalendar.date(
    byAdding: .day, 
    value: 1, 
    to: localCalendar.startOfDay(for: currentDate)
) ?? currentDate

// After sunset and before midnight = "Tonight"
return currentDate >= sunTimes.sunset && currentDate < startOfTomorrow
```

## Changes Made

**File:** `WeatherSensorCards.swift`

- Updated `isNighttime()` function in `OutdoorTemperatureCard` to check for midnight boundary
- Added proper timezone handling using the station's configured timezone
- Added detailed comments explaining the logic
- Ensured consistency with the ForecastCard's implementation

## Visual Behavior

### Before the Fix:
```
[Evening - 8 PM]    Tonight's Forecast 🌙
[Night - 11 PM]     Tonight's Forecast 🌙
[Midnight - 12 AM]  Tonight's Forecast 🌙  ← WRONG
[Early AM - 3 AM]   Tonight's Forecast 🌙  ← WRONG
[Morning - 6 AM]    Tonight's Forecast 🌙  ← WRONG
[Sunrise - 7 AM]    Today's Forecast ☀️
```

### After the Fix:
```
[Evening - 8 PM]    Tonight's Forecast 🌙
[Night - 11 PM]     Tonight's Forecast 🌙
[Midnight - 12 AM]  Today's Forecast ☀️  ← FIXED
[Early AM - 3 AM]   Today's Forecast ☀️  ← FIXED
[Morning - 6 AM]    Today's Forecast ☀️  ← FIXED
[Sunrise - 7 AM]    Today's Forecast ☀️
```

## Testing Recommendations

1. **Test Midnight Transition:**
   - Watch the Outdoor Temperature card around midnight
   - Verify it changes from "Tonight's Forecast" to "Today's Forecast" at 12:00 AM

2. **Test Early Morning:**
   - Check the card between midnight and sunrise (e.g., 3 AM)
   - Verify it shows "Today's Forecast" (not "Tonight's Forecast")

3. **Test Evening:**
   - Check the card after sunset but before midnight
   - Verify it shows "Tonight's Forecast"

4. **Test Different Timezones:**
   - If you have stations in different timezones, verify each respects its local midnight

5. **Compare with ForecastCard:**
   - Open the 5-Day Forecast card
   - The "Rest of Day" / "Rest of Tonight" section should match the Outdoor Temperature card's logic

## Technical Notes

- The fix uses the station's configured timezone (`station.timeZone`) for proper midnight calculation
- Both cards now use identical logic for determining "tonight" vs "today"
- The moon phase emoji display is unaffected - it still shows correctly at night based on actual daylight hours
- The fix is timezone-aware and will work correctly for stations in any timezone

## Files Modified

1. **WeatherSensorCards.swift**
   - Updated `isNighttime()` function in `OutdoorTemperatureCard` struct
   - Added midnight boundary check
   - Improved comments for clarity

## No Breaking Changes

This fix only affects the display text ("Tonight's" vs "Today's"). All other functionality remains unchanged:
- Moon phase display still works correctly
- Forecast data is unchanged
- Other cards are not affected
