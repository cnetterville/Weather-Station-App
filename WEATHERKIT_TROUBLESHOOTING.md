# WeatherKit Authentication Troubleshooting

## Error: "Failed to generate jwt token for: com.apple.weatherkit.authservice"

This error occurs when WeatherKit cannot authenticate your app. Here's how to fix it:

## Step 1: Verify Entitlements File Created

✅ **Done**: Created `Weather Station App.entitlements` with:
- `com.apple.developer.weatherkit` = true
- Required sandboxing permissions

**Location**: `/Weather Station App/Weather Station App.entitlements`

## Step 2: Add WeatherKit Capability in Xcode

1. Open your project in Xcode
2. Select the **Weather Station App** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** button
5. Search for and select **WeatherKit**
6. Xcode will automatically update the entitlements file

### Visual Guide: