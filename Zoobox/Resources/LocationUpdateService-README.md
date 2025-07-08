# 📍 LocationUpdateService Documentation Hub

## 📚 Available Documentation

This service includes comprehensive documentation to help developers understand, use, and maintain the location update functionality.

### 📖 **Documentation Files**

| Document | Description | Audience |
|----------|-------------|----------|
| **[LocationUpdateService-Documentation.md](./LocationUpdateService-Documentation.md)** | Complete technical documentation with architecture, implementation details, and examples | Developers, Architects |
| **[LocationUpdateService-Quick-Reference.md](./LocationUpdateService-Quick-Reference.md)** | Quick reference guide with common tasks and troubleshooting | Developers, Support |

### 🎯 **Quick Links**

- **Getting Started**: See [Quick Reference - Getting Started](./LocationUpdateService-Quick-Reference.md#-getting-started)
- **API Details**: See [Documentation - API Integration](./LocationUpdateService-Documentation.md#-api-integration)
- **Troubleshooting**: See [Quick Reference - Common Issues](./LocationUpdateService-Quick-Reference.md#-common-issues--solutions)
- **Testing**: See [Documentation - Testing Scenarios](./LocationUpdateService-Documentation.md#-testing-scenarios)

## 🚀 **Service Overview**

The LocationUpdateService automatically posts user location updates to `https://mikmik.site/Location_updater.php` in these scenarios:

### ⚡ **Automatic Triggers**
- **App Lifecycle**: Start, close, background, device lock
- **Timer**: Every 10 minutes
- **WebView**: On page refresh/reload
- **Manual**: Programmatic triggers

### 🔒 **Privacy & Security**
- ✅ Only operates with location permission granted
- ✅ Only posts when `user_id` cookie exists
- ✅ Validates location accuracy (< 50 meters)
- ✅ Lazy initialization prevents premature permission dialogs

### 📊 **Monitoring**
- Real-time status tracking
- Update success counter
- Comprehensive debug logging
- Debug information API

## 🛠️ **Developer Quick Start**

```swift
// Service runs automatically - no setup required

// Check status
print(LocationUpdateService.shared.lastUpdateStatus)
print("Updates sent: \(LocationUpdateService.shared.totalUpdatesSent)")

// Manual trigger
LocationUpdateService.shared.manualLocationUpdate()

// Debug info
Task {
    let debug = await LocationUpdateService.shared.getDebugInfo()
    print("Debug Info: \(debug)")
}
```

## 🔍 **Debug Console**

Look for logs with the `📍 [LocationUpdateService]` prefix:

```
📍 [LocationUpdateService] Location update triggered by: webview_refresh
📍 [LocationUpdateService] Found user_id cookie: abc123...
📍 [LocationUpdateService] 🚀 POSTING LOCATION TO API
📍 [LocationUpdateService] ✅ Location update successful
```

## 📋 **Requirements Checklist**

Before location updates work, ensure:

- ✅ Location permission granted (`authorizedWhenInUse` or `authorizedAlways`)
- ✅ `user_id` cookie exists in WebView cookie store
- ✅ Location accuracy < 50 meters
- ✅ Network connectivity available

## 🚨 **Common Issues**

| Issue | Quick Fix |
|-------|-----------|
| No updates sent | Check location permission + user_id cookie |
| Permission dialog on launch | Verify lazy initialization |
| Poor accuracy errors | Move to area with better GPS signal |
| API errors | Check network + server status |

## 🔗 **Integration Points**

The service is automatically integrated at these points:

1. **AppDelegate.swift** - Service initialization
2. **MainViewController.swift** - WebView refresh triggers
3. **System Events** - App lifecycle observers

## 📱 **API Specification**

### Request
```http
POST https://mikmik.site/Location_updater.php
Content-Type: application/json

{
    "user_id": "string",
    "latitude": double,
    "longitude": double,
    "accuracy": double
}
```

### Response (Success)
```json
{
    "success": true,
    "message": "Location updated successfully",
    "data": { ... }
}
```

### Response (Error)
```json
{
    "success": false,
    "message": "Error description"
}
```

---

## 📞 **Support**

For issues or questions:

1. **Check Console Logs**: Look for `📍 [LocationUpdateService]` prefix
2. **Run Debug Command**: `await LocationUpdateService.shared.getDebugInfo()`
3. **Consult Documentation**: Detailed guides available above
4. **Contact Team**: Development team for complex issues

---

*Last Updated: December 2024*  
*Version: 1.2* 