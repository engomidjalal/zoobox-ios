# 🔥 FCM Token Cookie Coverage Summary

## Overview
This document summarizes all the places where FCM tokens are automatically saved as cookies to ensure comprehensive coverage and no missed tokens.

## 📍 FCM Token Cookie Saving Points

### 1. **App Launch (AppDelegate)**
**Location**: `AppDelegate.swift` - `setupFCMTokenCookieManager()`
**Trigger**: App initialization
**Action**: Gets existing FCM token and saves as cookie
```swift
Messaging.messaging().token { token, error in
    if let token = token {
        fcmTokenManager.saveFCMTokenAsCookie(token)
    }
}
```

### 2. **FCM Token Refresh (AppDelegate)**
**Location**: `AppDelegate.swift` - `messaging(_:didReceiveRegistrationToken:)`
**Trigger**: Firebase generates new FCM token
**Action**: Immediately saves new token as cookie
```swift
func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let token = fcmToken {
        FCMTokenCookieManager.shared.saveFCMTokenAsCookie(token)
    }
}
```

### 3. **App Becomes Active (AppDelegate)**
**Location**: `AppDelegate.swift` - `applicationDidBecomeActive(_:)`
**Trigger**: App transitions from background to foreground
**Action**: Forces save of current FCM token as cookie
```swift
func applicationDidBecomeActive(_ application: UIApplication) {
    FCMTokenCookieManager.shared.forceSaveCurrentFCMTokenAsCookie()
}
```

### 4. **Main View Appears (MainViewController)**
**Location**: `MainViewController.swift` - `viewDidAppear(_:)`
**Trigger**: Main view controller becomes visible
**Action**: Forces save of current FCM token as cookie
```swift
override func viewDidAppear(_ animated: Bool) {
    fcmTokenCookieManager.forceSaveCurrentFCMTokenAsCookie()
}
```

### 5. **User Login (MainViewController)**
**Location**: `MainViewController.swift` - `userDidLogin(_:)`
**Trigger**: User successfully logs in
**Action**: Forces save of current FCM token as cookie
```swift
@objc private func userDidLogin(_ notification: Notification) {
    fcmTokenCookieManager.forceSaveCurrentFCMTokenAsCookie()
}
```

### 6. **WebView Setup (MainViewController)**
**Location**: `MainViewController.swift` - `setupFCMTokenCookie()`
**Trigger**: WebView configuration
**Action**: Validates and saves FCM token as cookie if missing
```swift
private func setupFCMTokenCookie() {
    Task {
        if await fcmTokenCookieManager.validateFCMTokenCookie() {
            // Cookie is valid
        } else {
            fcmTokenCookieManager.refreshFCMToken()
        }
    }
}
```

### 7. **Page Load Complete (MainViewController)**
**Location**: `MainViewController.swift` - `webView(_:didFinish:)`
**Trigger**: WebView finishes loading a page
**Action**: Validates and verifies FCM token cookie status
```swift
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    Task {
        if await fcmTokenCookieManager.validateFCMTokenCookie() {
            // Cookie is valid
        } else {
            fcmTokenCookieManager.refreshFCMToken()
        }
        await fcmTokenCookieManager.verifyFCMTokenCookieStatus()
    }
}
```

## 🔄 Enhanced FCM Token and User ID Cookie Management

### **NEW: Cookie Change Monitoring**
**Location**: `FCMTokenCookieManager.swift` - `cookiesDidChange(_:)`
**Trigger**: Any cookie change in WebView
**Action**: Monitors for both FCM_token and user_id cookie changes
```swift
func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
    Task {
        // Check if FCM token cookie changed
        // Check if user_id cookie changed and both cookies are now available
        await checkAndPostBothCookiesIfAvailable()
    }
}
```

### **NEW: Page Refresh Trigger**
**Location**: `MainViewController.swift` - `webView(_:didFinish:)`
**Trigger**: Every page refresh/load completion
**Action**: Checks and posts both cookies to API if available
```swift
// Check and post both cookies to API if available (on every page refresh)
await fcmTokenCookieManager.checkAndPostCookiesOnPageRefresh()
```

### **NEW: User ID Cookie Tracking**
**Location**: `FCMTokenCookieManager.swift` - `checkAndPostBothCookiesIfAvailable()`
**Trigger**: Cookie changes or manual checks
**Action**: Tracks user_id cookie changes and posts to API when both cookies are available
```swift
private func checkAndPostBothCookiesIfAvailable() async {
    let fcmToken = await getFCMTokenFromCookie()
    let userId = await extractUserIdFromCookies()
    
    // Check if user_id cookie changed
    if let userId = userId, !userId.isEmpty {
        if previousUserId != userId {
            print("🔥 user_id cookie changed from '\(previousUserId?.prefix(10) ?? "nil")' to '\(userId.prefix(10))'")
            previousUserId = userId
        }
    }
    
    if let fcmToken = fcmToken, !fcmToken.isEmpty,
       let userId = userId, !userId.isEmpty {
        await postFCMTokenAndUserIdIfNeeded()
    }
}
```

## 🎯 API Posting Scenarios

### **Scenario 1: FCM Token Exists, User ID Gets Set**
1. App starts with FCM token cookie
2. User logs in and user_id cookie gets set
3. Cookie change detected
4. Both cookies available → POST to API

### **Scenario 2: Page Refresh with Both Cookies**
1. User refreshes page
2. Page load completes
3. Both cookies checked
4. Both cookies available → POST to API

### **Scenario 3: User ID Changes**
1. User logs out and logs in with different account
2. user_id cookie changes
3. Cookie change detected
4. Both cookies available → POST to API

### **Scenario 4: Manual Trigger**
1. Developer calls `checkAndPostBothCookies()`
2. Both cookies checked
3. Both cookies available → POST to API

## 📊 API Endpoint Details

### **URL**: `https://mikmik.site/FCM_token_updater.php`
### **Method**: POST
### **Content-Type**: `application/x-www-form-urlencoded`
### **Body**: `user_id={userId}&FCM_token={fcmToken}&device_type=ios`

## 🔍 Debug Information

### **Enhanced Debug Info**
```swift
let debugInfo = await fcmTokenCookieManager.getDebugInfo()
// Returns:
// - cookie_fcm_token: Token from cookie
// - saved_fcm_token: Token from UserDefaults
// - current_fcm_token: Current token in memory
// - is_token_saved: Whether token is saved
// - current_user_id: Current user_id from cookie
// - previous_user_id: Previous user_id value
// - domain: Cookie domain
// - cookie_name: Cookie name
```

### **Manual Trigger Methods**
```swift
// Check and post both cookies if available
await fcmTokenCookieManager.checkAndPostBothCookies()

// Post both cookies to API (if available)
await fcmTokenCookieManager.postBothCookiesToAPI()

// Check on page refresh
await fcmTokenCookieManager.checkAndPostCookiesOnPageRefresh()
```

## 🧪 Testing Scenarios

### **Test Cases**
1. **App Launch**: Verify FCM token persists and is saved
2. **App Restart**: Verify token is saved when app becomes active
3. **User Login**: Verify token is saved when user logs in
4. **Page Navigation**: Verify token is verified on each page load
5. **Token Refresh**: Verify new tokens are saved when Firebase refreshes
6. **User ID Change**: Verify API posting when user_id cookie changes
7. **Page Refresh**: Verify API posting on every page refresh
8. **Both Cookies Available**: Verify API posting when both cookies exist

### **Verification Commands**
```swift
// Check current status
await fcmTokenCookieManager.verifyFCMTokenCookieStatus()

// Force save current token
fcmTokenCookieManager.forceSaveCurrentFCMTokenAsCookie()

// Get debug info
let debugInfo = await fcmTokenCookieManager.getDebugInfo()

// Manually trigger check
await fcmTokenCookieManager.checkAndPostBothCookies()
```

---

*This comprehensive coverage ensures that FCM tokens are never missed and are always available as cookies for the web application, with enhanced monitoring for user_id cookie changes and automatic API posting when both cookies are available.* 