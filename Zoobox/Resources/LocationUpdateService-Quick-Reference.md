# 📍 LocationUpdateService - Quick Reference

## 🚀 Getting Started

### Basic Usage

```swift
// Service is automatically initialized in AppDelegate
// No manual setup required

// Check status
print(LocationUpdateService.shared.lastUpdateStatus)
print("Updates sent: \(LocationUpdateService.shared.totalUpdatesSent)")

// Manual trigger
LocationUpdateService.shared.manualLocationUpdate()

// Debug info
Task {
    let debug = await LocationUpdateService.shared.getDebugInfo()
    print(debug)
}
```

### Requirements Checklist

- ✅ Location permission granted (`authorizedWhenInUse` or `authorizedAlways`)
- ✅ `user_id` cookie exists in WebView cookie store
- ✅ Location accuracy < 50 meters
- ✅ Network connectivity available

## 🎯 Automatic Triggers

| Trigger | When | Code Example |
|---------|------|--------------|
| App Start | User opens app | Automatic |
| App Background | User switches apps | Automatic |
| App Close | User terminates app | Automatic |
| Device Lock | Screen locks | Automatic |
| Timer | Every 10 minutes | Automatic |
| WebView Refresh | Page reload | `LocationUpdateService.shared.onWebViewRefresh()` |
| Manual | On demand | `LocationUpdateService.shared.manualLocationUpdate()` |

## 🔧 Integration Points

### AppDelegate.swift
```swift
// ✅ Already integrated - no changes needed
private func setupLocationUpdateService() {
    let locationService = LocationUpdateService.shared
    print("📍 AppDelegate: Location update service initialized")
}
```

### MainViewController.swift
```swift
// ✅ Already integrated - no changes needed
private func setupLocationUpdateService() {
    // Auto-starts if permission granted
}

func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    // ✅ Already integrated
    LocationUpdateService.shared.onWebViewRefresh()
}
```

## 📊 Status Monitoring

### Real-time Properties
```swift
let service = LocationUpdateService.shared

// Published properties (observable)
@Published var lastUpdateStatus: String    // Current status
@Published var totalUpdatesSent: Int      // Success counter
```

### Status Values
```
"Not started"                    // Initial state
"Location permission denied"     // No location access
"user_id cookie not found"      // User not logged in
"Failed to get location"        // GPS error
"Location accuracy too poor"    // Accuracy >= 50m
"✅ Success (trigger_name)"     // Posted successfully
"❌ API Error: message"         // Server error
"Network error: description"    // Connection issue
```

## 🐛 Debug Commands

### Console Logging
```swift
// Enable debug logging (always on)
// Look for 📍 [LocationUpdateService] prefix in console
```

### Manual Testing
```swift
// Test location update
LocationUpdateService.shared.manualLocationUpdate()

// Check current location permission
let authStatus = CLLocationManager.authorizationStatus()
print("Auth status: \(authStatus.rawValue)")

// Verify user_id cookie exists
Task {
    let cookies = try await WKWebsiteDataStore.default().httpCookieStore.allCookies()
    let userIdCookie = cookies.first { $0.name == "user_id" && $0.domain.contains("mikmik.site") }
    print("user_id cookie: \(userIdCookie?.value ?? "not found")")
}
```

### Debug Information
```swift
Task {
    let debug = await LocationUpdateService.shared.getDebugInfo()
    for (key, value) in debug {
        print("\(key): \(value)")
    }
}
```

## 🚨 Common Issues & Solutions

### Issue: No updates sent
**Check:**
1. Location permission granted? 
2. user_id cookie exists?
3. Network connectivity?
4. Location accuracy < 50m?

### Issue: Permission dialog on app launch
**Solution:** Check for early CLLocationManager initialization

### Issue: Updates fail with accuracy error
**Solution:** Wait for better GPS signal (move to open area)

### Issue: API returns error
**Check:**
1. API endpoint accessible?
2. Valid user_id format?
3. Server logs for details?

## 📱 API Details

### Endpoint
```
POST https://mikmik.site/Location_updater.php
Content-Type: application/json
```

### Request
```json
{
    "user_id": "string",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "accuracy": 15.0
}
```

### Response (Success)
```json
{
    "success": true,
    "message": "Location updated successfully",
    "data": {
        "user_id": "...",
        "latitude": 37.7749,
        "longitude": -122.4194,
        "accuracy": 15.0,
        "location_updated_at": "2024-12-XX XX:XX:XX",
        "timezone": "Asia/Baghdad"
    }
}
```

### Response (Error)
```json
{
    "success": false,
    "message": "Location not updated. Accuracy must be less than 50 meters"
}
```

## ⚙️ Configuration

### Modify Update Interval
```swift
// In LocationUpdateService.swift
private let updateInterval: TimeInterval = 600 // 10 minutes

// Change value and restart app
```

### Modify Accuracy Requirements
```swift
// In LocationUpdateService.swift
locationManager?.desiredAccuracy = kCLLocationAccuracyBest
locationManager?.distanceFilter = 10.0

// API accuracy check
guard location.horizontalAccuracy < 50.0 else { return }
```

## 🔄 Service Lifecycle

```
App Launch → Service Init → Setup Observers → Wait for Triggers
                ↓
Trigger Event → Check Permission → Check Cookie → Get Location
                ↓
Validate Accuracy → POST to API → Update Status → Log Result
```

---

**💡 Pro Tips:**
- Service runs automatically - no manual intervention needed
- Check console logs with 📍 prefix for detailed debugging
- Use `getDebugInfo()` for comprehensive status overview
- Location updates are cached for 5 minutes to improve performance 