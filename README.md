# Weather Station App

A modern macOS application for monitoring multiple Ecowitt weather stations with real-time data, historical analytics, weather radar, and forecasting capabilities.

## Features

### 🌡️ Multi-Station Support
- Monitor multiple Ecowitt weather stations simultaneously
- Automatic station discovery via Ecowitt API
- Custom labels and organization for each station
- Independent configuration per station

### 📊 Comprehensive Weather Data
- **Temperature & Humidity**: Outdoor, indoor, and multi-channel sensors
- **Wind Monitoring**: Speed, direction, gusts with compass visualization
- **Rainfall Tracking**: Both traditional and piezo rain gauges
- **Air Quality**: PM2.5 monitoring across multiple channels
- **Atmospheric Data**: Barometric pressure with trend analysis
- **Lightning Detection**: Distance tracking and strike counting
- **Solar & UV**: Solar radiation and UV index monitoring
- **Battery Status**: Health monitoring for all wireless sensors

### 🎯 Advanced Analytics
- **Historical Data**: 5min to daily resolution over multiple years
- **Daily High/Low Tracking**: Temperature and humidity extremes
- **Interactive Charts**: Customizable time ranges and data visualization
- **Lightning Analysis**: 30-day strike history and detection patterns
- **Timezone Support**: Accurate timestamps across different locations

### 🌦️ Weather Integration
- **Live Radar**: Integrated Windy.com radar with auto-refresh
- **5-Day Forecast**: Detailed weather predictions with emoji icons
- **Sunrise/Sunset**: Accurate astronomical calculations with day length
- **Moon Phases**: Lunar calendar with rise/set times

### 📱 Menu Bar Integration
- Real-time temperature display in menu bar
- Customizable station selection for menu bar display
- Background refresh when main app is closed
- Quick access to main application

### ⚙️ Smart Performance
- **Memory Optimization**: Automatic cleanup and pressure monitoring
- **Concurrent API Calls**: Optimized data fetching with rate limiting
- **Smart Caching**: Prevents unnecessary API requests
- **Battery Efficiency**: Adaptive refresh rates and background processing

## Requirements

- **macOS**: 12.0 (Monterey) or later
- **Hardware**: Intel or Apple Silicon Mac
- **Internet**: Required for API access and radar data
- **Ecowitt Account**: Weather station registered with Ecowitt

## Installation

1. Clone the repository: