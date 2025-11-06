# WeatherKit Setup Guide

## Overview

This app has been migrated from Open-Meteo API to Apple's native **WeatherKit** for weather forecasts. WeatherKit provides more reliable, accurate, and native weather data.

## Setup Instructions

### 1. Add WeatherKit Capability

1. Open the project in Xcode
2. Select the **Weather Station App** target
3. Go to the **Signing & Capabilities** tab
4. Click the **+ Capability** button
5. Search for and add **WeatherKit**

### 2. Configure Your Apple Developer Account

WeatherKit requires:
- An active Apple Developer Program membership
- Proper App ID configuration with WeatherKit enabled

The capability will automatically:
- Add the WeatherKit entitlement to your app
- Register your App ID with WeatherKit service
- Enable API access

### 3. API Usage Limits

- **Free Tier**: 500,000 API calls per month
- **Typical Usage**: ~5-10 calls per day per weather station
- **Caching**: The app caches forecasts for 3 hours to minimize API usage

### 4. How It Works

The app uses WeatherKit to fetch:
- **Daily Forecasts**: 5-day forecast with high/low temperatures, precipitation, wind
- **Hourly Forecasts**: 48-hour detailed hourly predictions
- **Current Conditions**: Real-time weather data

All forecasts are based on the coordinates provided by your Ecowitt weather stations.

## Migration Details

### What Changed

- **Service**: Open-Meteo → WeatherKit
- **Authentication**: None required → Apple Developer Account
- **Rate Limits**: Free but limited → 500k calls/month
- **Data Quality**: Good → Excellent (Apple's proprietary data)

### What Stayed the Same

- All UI components remain unchanged
- Data models (`WeatherForecast`, `DailyWeatherForecast`, `HourlyWeatherForecast`) unchanged
- Weather code system (0-99) maintained for compatibility
- Temperature, wind, and precipitation formatting unchanged

### Weather Code Mapping

WeatherKit's `WeatherCondition` enum is automatically mapped to numeric codes:
- `0`: Clear sky
- `1`: Mainly clear
- `2`: Partly cloudy
- `3`: Overcast
- `45-48`: Fog conditions
- `51-67`: Rain/drizzle conditions
- `71-86`: Snow conditions
- `95-99`: Thunderstorms

## Troubleshooting

### "WeatherKit is not available"

**Solution**: Ensure you've:
1. Added the WeatherKit capability
2. Signed the app with a valid Apple Developer account
3. Run on a device/simulator with internet access

### "Failed to fetch forecast"

**Solution**: Check:
1. Weather station has valid coordinates (latitude/longitude)
2. Internet connection is active
3. Apple Developer account is in good standing

### Exceeding API Limits

If you exceed 500,000 calls/month:
- Increase cache duration (currently 3 hours)
- Reduce number of weather stations
- Contact Apple for enterprise pricing

## Code Reference

### Main Service
- **File**: `WeatherForecastService.swift`
- **Class**: `WeatherForecastService`
- **Key Method**: `fetchForecast(for:)`

### Models
- **File**: `WeatherForecastModels.swift`
- **Structures**: `WeatherForecast`, `DailyWeatherForecast`, `HourlyWeatherForecast`

### Mapper
- **Structure**: `WeatherConditionMapper`
- **Purpose**: Maps WeatherKit conditions to numeric weather codes

## Support

For WeatherKit-specific issues:
- [Apple WeatherKit Documentation](https://developer.apple.com/documentation/weatherkit)
- [WeatherKit REST API](https://developer.apple.com/documentation/weatherkitrestapi)

For app-specific issues:
- Check the project README.md
- Review LOGGING_MIGRATION_GUIDE.md for debug logging