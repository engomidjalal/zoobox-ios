# 🔗 FCM Deep Linking Implementation

## Overview

The Zoobox app now supports deep linking for FCM (Firebase Cloud Messaging) notifications based on order type. When a user taps on a notification, the app will automatically open the appropriate tracking URL in the WebView.

## 🔧 Implementation Details

### Notification Data Structure

FCM notifications must include the following data fields:
- `order_type`: Either "food" or "d2d"
- `order_id`: The unique order identifier

### Deep Link URLs

Based on the `order_type`, the app will open different URLs:

#### Food Orders
- **URL Pattern**: `https://mikmik.site/track_order.php?order_id={order_id}`
- **Example**: `https://mikmik.site/track_order.php?order_id=12345`

#### D2D Orders
- **URL Pattern**: `https://mikmik.site/d2d/track_d2d.php?order_id={order_id}`
- **Example**: `https://mikmik.site/d2d/track_d2d.php?order_id=12345`

## 📱 How It Works

### 1. Notification Tap Handling (AppDelegate)
When a user taps on a notification, the `AppDelegate` processes the notification data:

```swift
func userNotificationCenter(_ center: UNUserNotificationCenter,
                            didReceive response: UNNotificationResponse,
                            withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    handleFCMNotificationDeepLink(userInfo: userInfo)
    completionHandler()
}
```

### 2. Deep Link URL Construction
The app extracts `order_type` and `order_id` from the notification and constructs the appropriate URL:

```swift
switch orderType.lowercased() {
case "food":
    let urlString = "https://mikmik.site/track_order.php?order_id=\(orderId)"
case "d2d":
    let urlString = "https://mikmik.site/d2d/track_d2d.php?order_id=\(orderId)"
}
```

### 3. URL Opening
The constructed URL is opened in the WebView through the MainViewController:

```swift
// Post notification to open URL in main view controller
NotificationCenter.default.post(
    name: NSNotification.Name("OpenDeepLinkURL"),
    object: nil,
    userInfo: ["url": url]
)
```

### 4. App Launch from Notification
If the app is launched from a notification (not running), the SceneDelegate handles the launch and stores the URL to be opened when the MainViewController is ready.

## 🔄 Flow Scenarios

### Scenario 1: App in Foreground
1. User receives FCM notification
2. User taps notification
3. AppDelegate processes notification data
4. Deep link URL is constructed
5. URL is immediately opened in WebView

### Scenario 2: App in Background
1. User receives FCM notification
2. User taps notification
3. App comes to foreground
4. AppDelegate processes notification data
5. Deep link URL is constructed and opened

### Scenario 3: App Not Running
1. User receives FCM notification
2. User taps notification
3. App launches
4. SceneDelegate processes launch options
5. URL is stored and opened when MainViewController is ready

## 🧪 Testing

To test the deep linking functionality:

1. **Send FCM notification with food order data:**
   ```json
   {
     "order_type": "food",
     "order_id": "12345"
   }
   ```

2. **Send FCM notification with d2d order data:**
   ```json
   {
     "order_type": "d2d",
     "order_id": "67890"
   }
   ```

3. **Expected behavior:**
   - Food notification should open: `https://mikmik.site/track_order.php?order_id=12345`
   - D2D notification should open: `https://mikmik.site/d2d/track_d2d.php?order_id=67890`

## 📋 Requirements

- FCM notifications must include `order_type` and `order_id` fields
- `order_type` must be either "food" or "d2d" (case-insensitive)
- `order_id` must be a valid string identifier
- App must have proper FCM setup and permissions

## 🔍 Debug Logging

The implementation includes comprehensive logging for debugging:

- `🔔 Notification tapped:` - When notification is tapped
- `🔗 Processing FCM notification for deep linking` - When processing notification data
- `🔗 Order Type: X, Order ID: Y` - Extracted order information
- `🔗 Food/D2D order deep link: URL` - Constructed deep link URL
- `🔗 Opening deep link URL: URL` - When opening the URL
- `🔗 Handling FCM deep link: URL` - When MainViewController receives the URL

## 🚀 Benefits

1. **Seamless User Experience** - Users can directly access order tracking from notifications
2. **Type-Specific Routing** - Different order types open appropriate tracking pages
3. **Robust Handling** - Works in all app states (foreground, background, not running)
4. **Error Handling** - Graceful handling of missing or invalid notification data
5. **Debug Support** - Comprehensive logging for troubleshooting 