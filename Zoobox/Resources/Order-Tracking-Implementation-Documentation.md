# Order Tracking Implementation Documentation

## Overview

This document describes the comprehensive order tracking implementation for iOS 15+ that mirrors the behavior of the Android app. The system provides real-time order status updates with background processing, notifications, and deep linking capabilities.

## Architecture

The order tracking system consists of several key components:

### Core Services

1. **OrderTrackingService** - Main coordinator service
2. **OrderTrackingAPIClient** - API communication layer
3. **OrderNotificationManager** - Notification handling
4. **OrderTrackingCookieManager** - Cookie and user ID management
5. **BackgroundTaskManager** - Background task scheduling
6. **ToastManager** - Foreground notification display

### Data Models

- **OrderResponse** - API response structure
- **OrderNotification** - Individual order notification
- **OrderStatusType** - Order status enumeration
- **TrackingState** - Persistence state
- **BackgroundTaskConfig** - Configuration constants

## Key Features

### 1. Background Processing (iOS 15+)

- Uses `BGTask` framework with `BGAppRefreshTask` and `BGProcessingTask`
- Multiple restart mechanisms with different intervals
- Proper task expiration handling
- Background URL session support

### 2. API Integration

- Connects to `https://mikmik.site/notification_checker.php`
- Sends GET requests with `user_id` parameter
- 15-second polling interval in foreground
- Retry logic with exponential backoff
- Network connectivity monitoring

### 3. Cookie Management

- Extracts `user_id` from `WKWebsiteDataStore` cookies
- Monitors cookie changes with `WKHTTPCookieStoreObserver`
- Fallback to `UserDefaults` if cookies unavailable
- Automatic cookie validation and refresh

### 4. Notification System

- Local notifications for different order statuses
- Custom notification categories and actions
- Haptic feedback integration
- Toast messages for foreground notifications
- Deep linking to order tracking pages

### 5. User Experience

- SwiftUI status view with real-time updates
- Debug information panel
- Connection status monitoring
- Error handling and user feedback

## Configuration

### Info.plist Requirements

```xml
<key>UIBackgroundModes</key>
<array>
    <string>background-fetch</string>
    <string>background-processing</string>
    <string>location</string>
    <string>remote-notification</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.zoobox.orderTrackingRefresh</string>
    <string>com.zoobox.orderTrackingProcessing</string>
</array>
```

### AppDelegate Integration

```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Register background tasks
    BackgroundTaskManager.shared.registerBackgroundTasks()
    return true
}

func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
    // Handle background URL session completion
    completionHandler()
}
```

### SceneDelegate Integration

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    // Handle deep links for order tracking
    guard let url = URLContexts.first?.url else { return }
    handleDeepLink(url: url)
}
```

## Usage

### Starting Order Tracking

```swift
// Start tracking (automatically requests permissions)
await OrderTrackingService.shared.startTracking()

// Check if tracking is active
let isTracking = OrderTrackingService.shared.isTracking
```

### Stopping Order Tracking

```swift
// Stop tracking
OrderTrackingService.shared.stopTracking()

// Clean up all data
OrderTrackingService.shared.cleanup()
```

### Manual API Check

```swift
// Check for new orders manually
guard let userId = await OrderTrackingCookieManager.shared.getUserId() else {
    return
}

let response = try await OrderTrackingAPIClient.shared.checkOrders(userId: userId)
```

### Notification Management

```swift
// Request notification permissions
let granted = await OrderNotificationManager.shared.requestPermissions()

// Schedule a notification
let notification = OrderNotification(...)
OrderNotificationManager.shared.scheduleNotification(for: notification)

// Show toast in foreground
OrderNotificationManager.shared.showToast(message: "Order updated", type: .arrival)
```

## API Response Format

The system expects the following JSON response format:

```json
{
  "success": true,
  "count": 1,
  "notifications": [
    {
      "order_id": "123",
      "type": "arrival",
      "message": "Hero arrived!",
      "hero": "John",
      "timestamp": "2024-01-01 12:00:00",
      "date": "2024-01-01"
    }
  ]
}
```

## Order Status Types

- **hero_assigned** - 👨‍🍳 Hero Assigned!
- **arrival** - 🚗 Hero Arrived!
- **pickup** - 📦 Order Picked Up!
- **delivered** - ✅ Order Delivered!

## Background Task Scheduling

The system uses multiple background task types:

1. **BGAppRefreshTask** (15 seconds) - For frequent updates
2. **BGProcessingTask** (5 minutes) - For longer operations
3. **Fallback Task** (10 minutes) - For retry scenarios

## Deep Linking

The system supports deep links to order tracking pages:

```
https://mikmik.site/track_order.php?order_id={order_id}&date={date}
```

## Error Handling

The system includes comprehensive error handling:

- Network connectivity issues
- API failures with retry logic
- Cookie expiration and re-authentication
- Background task limitations
- Service restart failures

## Debug Information

Access debug information for troubleshooting:

```swift
let debugInfo = await OrderTrackingService.shared.getDebugInfo()
```

Debug info includes:
- Tracking status
- Connection status
- Cookie information
- Background task status
- Notification authorization
- Error messages

## Integration with Existing App

### Adding Toast Overlay

```swift
// Add toast overlay to any view controller
class MainViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        addToastOverlay()
    }
}
```

### Order Tracking Status View

```swift
// Present order tracking status
let statusVC = OrderTrackingStatusViewController()
present(statusVC, animated: true)
```

## Testing

### Simulating Order Updates

1. Start order tracking
2. Use the debug panel to monitor status
3. Simulate API responses
4. Verify notifications and toasts

### Background Testing

1. Start tracking in foreground
2. Send app to background
3. Wait for background task execution
4. Check notification delivery

## Troubleshooting

### Common Issues

1. **Notifications not showing**
   - Check notification permissions
   - Verify background app refresh is enabled
   - Check device notification settings

2. **Background tasks not running**
   - Verify background modes in Info.plist
   - Check BGTaskSchedulerPermittedIdentifiers
   - Ensure proper task registration

3. **Cookies not available**
   - Check if user is logged in
   - Verify WKWebsiteDataStore access
   - Check UserDefaults fallback

4. **API connection issues**
   - Verify network connectivity
   - Check API endpoint accessibility
   - Review error logs

### Debug Commands

```swift
// Refresh cookies
await OrderTrackingCookieManager.shared.refreshCookies()

// Clear notification history
OrderNotificationManager.shared.clearNotificationHistory()

// Get pending background tasks
let tasks = await BackgroundTaskManager.shared.getPendingTasks()

// Validate cookies
let isValid = await OrderTrackingCookieManager.shared.validateCookies()
```

## Performance Considerations

- Background tasks are limited by iOS
- Network requests use exponential backoff
- Cookie monitoring is efficient with observers
- Notifications are deduplicated
- State is persisted efficiently

## Security

- User ID is extracted from secure cookies
- API requests use HTTPS
- No sensitive data is logged
- Background tasks are properly scoped

## Future Enhancements

1. Push notification support
2. Custom notification sounds
3. Advanced retry strategies
4. Analytics integration
5. Offline queue management
6. Multi-order tracking
7. Real-time location updates

## Support

For issues or questions about the order tracking implementation, refer to:
- Debug information panel
- Console logs with emoji prefixes
- Background task scheduler logs
- Network monitoring logs 