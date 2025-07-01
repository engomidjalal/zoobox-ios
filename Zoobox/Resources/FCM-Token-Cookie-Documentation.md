# 🔥 FCM Token Cookie Management Documentation

## Overview

The Zoobox app now includes automatic FCM (Firebase Cloud Messaging) token cookie management. Whenever an FCM token is generated or updated, it is automatically saved as a cookie named `FCM_token` in the WebView, making it available to the web application.

## 🔧 Implementation Details

### FCMTokenCookieManager Class

The `FCMTokenCookieManager` class handles all FCM token cookie operations:

```swift
@MainActor
class FCMTokenCookieManager: NSObject, ObservableObject {
    static let shared = FCMTokenCookieManager()
    
    // Save FCM token as a cookie
    func saveFCMTokenAsCookie(_ token: String?)
    
    // Get FCM token from cookie
    func getFCMTokenFromCookie() async -> String?
    
    // Update FCM token if changed
    func updateFCMTokenIfNeeded(_ newToken: String?)
    
    // Refresh FCM token from Firebase
    func refreshFCMToken()
    
    // Validate FCM token cookie
    func validateFCMTokenCookie() async -> Bool
}
```

### Key Features

#### 1. **Automatic Token Saving**
- FCM tokens are automatically saved as cookies when generated
- Cookie name: `FCM_token`
- Domain: `mikmik.site`
- Expiration: 1 year from creation

#### 2. **Token Change Detection**
- Monitors for FCM token changes
- Automatically updates cookie when token changes
- Prevents duplicate cookie creation

#### 3. **Cookie Persistence**
- Tokens are backed up to UserDefaults
- Survives app restarts and updates
- Automatic restoration when needed

#### 4. **WebView Integration**
- Cookies are available immediately in WebView
- No additional JavaScript injection required
- Seamless integration with existing web app

## 📱 Integration Points

### AppDelegate Integration

```swift
// Initialize FCM token cookie manager
private func setupFCMTokenCookieManager() {
    let fcmTokenManager = FCMTokenCookieManager.shared
    
    // Get existing FCM token and save as cookie
    Messaging.messaging().token { token, error in
        if let token = token {
            fcmTokenManager.saveFCMTokenAsCookie(token)
        }
    }
}

// FCM token received callback
func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let token = fcmToken {
        FCMTokenCookieManager.shared.saveFCMTokenAsCookie(token)
    }
}
```

### MainViewController Integration

```swift
// Setup FCM token cookie
private func setupFCMTokenCookie() {
    Task {
        if await fcmTokenCookieManager.validateFCMTokenCookie() {
            print("🔥 FCM token cookie is valid")
        } else {
            fcmTokenCookieManager.refreshFCMToken()
        }
    }
}

// Validate after page load
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    Task {
        if await fcmTokenCookieManager.validateFCMTokenCookie() {
            print("🔥 FCM token cookie validated after page load")
        } else {
            fcmTokenCookieManager.refreshFCMToken()
        }
    }
}
```

## 🔄 Token Lifecycle

### 1. **Initial Token Generation**
```
App Launch → Firebase Initialization → FCM Token Generated → Save as Cookie
```

### 2. **Token Refresh**
```
Firebase Token Refresh → New Token Received → Update Cookie if Changed
```

### 3. **Cookie Validation**
```
Page Load → Check Cookie Exists → Validate Token → Refresh if Missing
```

### 4. **Cookie Monitoring**
```
Cookie Store Changes → Detect FCM Token Changes → Update Internal State
```

## 🍪 Cookie Properties

### FCM Token Cookie Details
- **Name**: `FCM_token`
- **Domain**: `mikmik.site`
- **Path**: `/`
- **Expiration**: 1 year from creation
- **Secure**: No (HTTP and HTTPS)
- **HTTPOnly**: No (accessible via JavaScript)

### Example Cookie
```
Name: FCM_token
Value: fMEP0vJqS0:APA91bHqX...
Domain: mikmik.site
Path: /
Expires: 2026-06-27 10:30:00 +0000
```

## 🌐 Web Application Access

### JavaScript Access
```javascript
// Get FCM token from cookie
function getFCMToken() {
    const cookies = document.cookie.split(';');
    for (let cookie of cookies) {
        const [name, value] = cookie.trim().split('=');
        if (name === 'FCM_token') {
            return value;
        }
    }
    return null;
}

// Example usage
const fcmToken = getFCMToken();
if (fcmToken) {
    console.log('FCM Token available:', fcmToken);
    // Send to server or use for push notifications
}
```

### Server-Side Access
The web application can access the FCM token from the `FCM_token` cookie in server requests.

## 📊 Benefits

### For Users
- Seamless push notification setup
- No manual token management required
- Automatic token refresh handling
- Persistent token storage

### For Developers
- Automatic FCM token management
- Web app can access token immediately
- No additional API calls needed
- Robust error handling

### For Web Application
- Direct access to FCM token
- No need for separate token requests
- Consistent token availability
- Simplified push notification setup

## 🔍 Debugging and Monitoring

### Console Logs
The system provides detailed logging:
```
🔥 FCM Token received: fMEP0vJqS0:APA91bHqX...
🔥 FCM Token saved as cookie: fMEP0vJqS0:APA91bHqX...
🔥 FCM token cookie validated after page load
🔥 FCM token cookie changed: newTokenValue
```

### Debug Information
```swift
let debugInfo = await fcmTokenCookieManager.getDebugInfo()
// Returns:
// - cookie_fcm_token: Token from cookie
// - saved_fcm_token: Token from UserDefaults
// - current_fcm_token: Current token in memory
// - is_token_saved: Whether token is saved
// - domain: Cookie domain
// - cookie_name: Cookie name
```

## 🛠️ Usage Examples

### Manual Token Operations

```swift
// Save FCM token as cookie
fcmTokenCookieManager.saveFCMTokenAsCookie("your-fcm-token")

// Get FCM token from cookie
let token = await fcmTokenCookieManager.getFCMTokenFromCookie()

// Refresh FCM token
fcmTokenCookieManager.refreshFCMToken()

// Validate FCM token cookie
let isValid = await fcmTokenCookieManager.validateFCMTokenCookie()

// Clear FCM token cookie
await fcmTokenCookieManager.clearFCMTokenCookie()
```

### Error Handling

```swift
// Handle token refresh errors
fcmTokenCookieManager.refreshFCMToken()
// Errors are logged automatically

// Handle cookie creation errors
fcmTokenCookieManager.saveFCMTokenAsCookie(token)
// Errors are logged and handled gracefully
```

## 🔧 Configuration

### Cookie Settings
```swift
private let cookieName = "FCM_token"
private let domain = "mikmik.site"
private let userDefaultsKey = "FCM_Token_Backup"
```

### Expiration Settings
```swift
// Set expiration to 1 year from now
let expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
```

## 🚀 Best Practices

### 1. **Automatic Operation**
- Let the system handle FCM tokens automatically
- Manual intervention rarely needed

### 2. **Monitoring**
- Check console logs for token operations
- Monitor cookie validation results

### 3. **Testing**
- Test with app updates
- Test with token refresh scenarios
- Test with cookie clearing

### 4. **Security**
- FCM tokens are sensitive data
- Cookies are stored securely
- Automatic cleanup on app deletion

## 🔮 Future Enhancements

### Potential Improvements
1. **Encrypted Storage**: Add encryption for FCM tokens
2. **Token Rotation**: Implement automatic token rotation
3. **Multiple Domains**: Support multiple cookie domains
4. **Advanced Analytics**: Track token usage patterns
5. **Custom Expiry**: User-configurable token retention

### Monitoring Features
1. **Token Analytics**: Track token generation and usage
2. **Performance Metrics**: Monitor cookie operations
3. **Error Reporting**: Enhanced error tracking
4. **User Notifications**: Notify users of token issues

---

*This documentation covers the complete FCM token cookie management system implemented in Zoobox. The system ensures reliable FCM token management and provides seamless integration between the native app and web application.* 