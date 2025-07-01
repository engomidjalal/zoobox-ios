# 🔥 FCM Token and User ID Cookie Test Script

## Overview
This document provides a comprehensive test script to verify the enhanced FCM token and user_id cookie functionality.

## 🧪 Test Scenarios

### **Test 1: App Launch with FCM Token Only**
**Objective**: Verify FCM token is saved and API posting is skipped when user_id is missing

**Steps**:
1. Clear all cookies
2. Launch app
3. Verify FCM token is generated and saved as cookie
4. Check console logs for "Skipping POST: FCM_token or user_id missing"
5. Verify no API call is made

**Expected Results**:
```
🔥 FCM Token received: [token]
🔥 🔥 🔥 SAVING FCM TOKEN AS COOKIE: [token]
🔥 FCM Token saved as cookie: [token]
🔥 Not all required cookies available - FCM_token: [token_prefix], user_id: nil
🔥 [FCMTokenCookieManager] Skipping POST: FCM_token or user_id missing.
```

### **Test 2: User Login (User ID Cookie Set)**
**Objective**: Verify API posting when user_id cookie becomes available

**Steps**:
1. Ensure FCM token cookie exists from Test 1
2. Login to the web application
3. Verify user_id cookie is set
4. Check console logs for cookie change detection
5. Verify API call is made to FCM token updater

**Expected Results**:
```
🔥 user_id cookie changed from 'nil' to '[user_id_prefix]'
🔥 Both FCM_token and user_id cookies available - posting to API
🔥 [FCMTokenCookieManager] POSTING to FCM token updater API
🔥 FCM_token: [token_prefix]...
🔥 user_id: [user_id_prefix]...
🔥 device_type: ios
🔥 [FCMTokenCookieManager] POST response status: 200
```

### **Test 3: Page Refresh with Both Cookies**
**Objective**: Verify API posting on every page refresh

**Steps**:
1. Ensure both FCM_token and user_id cookies exist
2. Pull to refresh the page
3. Check console logs for page refresh trigger
4. Verify API call is made

**Expected Results**:
```
🌐 WebView finished loading successfully
🔥 Page refresh detected - checking and posting cookies if available
🔥 Both FCM_token and user_id cookies available - posting to API
🔥 [FCMTokenCookieManager] POSTING to FCM token updater API
🔥 device_type: ios
```

### **Test 4: User ID Cookie Change**
**Objective**: Verify API posting when user_id cookie changes

**Steps**:
1. Ensure both cookies exist
2. Logout and login with different user
3. Check console logs for user_id change detection
4. Verify API call is made with new user_id

**Expected Results**:
```
🔥 user_id cookie changed from '[old_user_id_prefix]' to '[new_user_id_prefix]'
🔥 Both FCM_token and user_id cookies available - posting to API
🔥 [FCMTokenCookieManager] POSTING to FCM token updater API
🔥 user_id: [new_user_id_prefix]...
🔥 device_type: ios
```

### **Test 5: FCM Token Refresh**
**Objective**: Verify API posting when FCM token changes

**Steps**:
1. Ensure both cookies exist
2. Force FCM token refresh
3. Check console logs for FCM token change
4. Verify API call is made with new FCM token

**Expected Results**:
```
🔥 🔥 🔥 FCM TOKEN CHANGED - SAVING NEW TOKEN AS COOKIE
🔥 Previous token: [old_token]
🔥 New token: [new_token]
🔥 FCM Token saved as cookie: [new_token]
🔥 Both FCM_token and user_id cookies available - posting to API
🔥 [FCMTokenCookieManager] POSTING to FCM token updater API
🔥 FCM_token: [new_token_prefix]...
🔥 device_type: ios
```

### **Test 6: Manual Trigger**
**Objective**: Verify manual API posting trigger

**Steps**:
1. Ensure both cookies exist
2. Call `fcmTokenCookieManager.checkAndPostBothCookies()`
3. Check console logs for manual trigger
4. Verify API call is made

**Expected Results**:
```
🔥 Both FCM_token and user_id cookies available - posting to API
🔥 [FCMTokenCookieManager] POSTING to FCM token updater API
🔥 device_type: ios
```

## 🔍 Debug Commands

### **Check Current Status**
```swift
// Get comprehensive debug info
let debugInfo = await fcmTokenCookieManager.getDebugInfo()
print("Debug Info: \(debugInfo)")

// Verify FCM token cookie status
await fcmTokenCookieManager.verifyFCMTokenCookieStatus()
```

### **Manual Triggers**
```swift
// Check and post both cookies
await fcmTokenCookieManager.checkAndPostBothCookies()

// Post both cookies to API
await fcmTokenCookieManager.postBothCookiesToAPI()

// Check on page refresh
await fcmTokenCookieManager.checkAndPostCookiesOnPageRefresh()
```

### **Force Operations**
```swift
// Force save current FCM token
fcmTokenCookieManager.forceSaveCurrentFCMTokenAsCookie()

// Refresh FCM token
fcmTokenCookieManager.refreshFCMToken()
```

## 📊 Expected Debug Info Output

```json
{
  "cookie_fcm_token": "fMEP0vJqS0:APA91bHqX...",
  "saved_fcm_token": "fMEP0vJqS0:APA91bHqX...",
  "current_fcm_token": "fMEP0vJqS0:APA91bHqX...",
  "is_token_saved": true,
  "current_user_id": "12345",
  "previous_user_id": "12345",
  "domain": "mikmik.site",
  "cookie_name": "FCM_token"
}
```

## 🚨 Error Scenarios

### **Network Error**
**Expected Behavior**: Log error and continue
```
🔥 [FCMTokenCookieManager] POST error: [error_description]
```

### **Invalid URL**
**Expected Behavior**: Log error and skip
```
🔥 [FCMTokenCookieManager] Invalid URL: [url]
```

### **Missing Cookies**
**Expected Behavior**: Log and skip
```
🔥 Not all required cookies available - FCM_token: nil, user_id: nil
🔥 [FCMTokenCookieManager] Skipping POST: FCM_token or user_id missing.
```

## ✅ Success Criteria

### **All Tests Must Pass**:
1. ✅ FCM token is saved as cookie on app launch
2. ✅ API posting is skipped when user_id is missing
3. ✅ API posting occurs when user_id becomes available
4. ✅ API posting occurs on every page refresh
5. ✅ API posting occurs when user_id changes
6. ✅ API posting occurs when FCM token changes
7. ✅ Manual triggers work correctly
8. ✅ Debug info shows correct values
9. ✅ Error handling works gracefully

### **Performance Requirements**:
- API calls should complete within 5 seconds
- Cookie monitoring should not impact app performance
- Page refresh should not be delayed by API calls

### **Reliability Requirements**:
- No duplicate API calls for the same cookie combination
- API calls should retry on network errors
- System should continue working if API is unavailable

---

*This test script ensures the enhanced FCM token and user_id cookie functionality works correctly in all scenarios.* 