# 🔐 Zoobox Permission System Documentation

## Overview

The Zoobox app includes a comprehensive permission management system with **real-time cookie tracking** that automatically monitors permission changes and stores statuses in UserDefaults. The system also allows the WebView to use permissions and request new permissions with clear explanations when needed.

## 🎯 Key Features

### ✅ **Automatic Permission Access**
- WebView automatically uses granted permissions without asking again
- No duplicate permission dialogs
- Seamless user experience

### ✅ **Smart Permission Requests**
- Requests permissions with clear explanations
- Explains why each permission is needed
- Guides users to Settings if denied

### ✅ **Real-time Permission Updates**
- WebView receives permission status updates in real-time
- JavaScript can react to permission changes
- UI can update based on permission status

### ✅ **Comprehensive Permission Coverage**
- **Location**: GPS and location services
- **Camera**: Photo capture and video recording
- **Notifications**: Push notifications and alerts

### ✅ **Real-time Cookie Tracking System**
- **Automatic monitoring**: Tracks permission changes across app lifecycle
- **UserDefaults storage**: Persistent permission cookies (`p_Location`, `p_Camera`, `p_Notification`)
- **Settings detection**: Automatically detects when user returns from Settings
- **ASAP updates**: Permission changes reflected immediately
- **Comprehensive logging**: Detailed console output for every operation

## 🏗️ Architecture

### Core Components

1. **PermissionManager** (`Managers/PermissionManager.swift`)
   - Central permission management
   - Handles all permission types
   - Provides WebView integration

2. **MainViewController** (`ViewControllers/MainViewController.swift`)
   - WebView integration
   - JavaScript bridge
   - Permission injection

3. **PermissionViewController** (`ViewControllers/PermissionViewController.swift`)
   - Initial app permission flow
   - Uses PermissionManager for consistency

4. **Permission Cookie System** (`PermissionManager.swift`)
   - Real-time permission tracking
   - UserDefaults storage for persistence
   - App state monitoring for Settings detection

## 🍪 Cookie Tracking System

### Permission Cookies
The system automatically creates and maintains permission cookies in UserDefaults:

- **`p_Location`** - Location permission status ("yes" / "no")
- **`p_Camera`** - Camera permission status ("yes" / "no") 
- **`p_Notification`** - Notification permission status ("yes" / "no")

### Real-time Monitoring
- **App Launch**: Initializes cookies with current permission status
- **Permission Requests**: Updates cookies immediately when permissions are granted/denied
- **Settings Changes**: Detects when user returns from Settings and updates cookies ASAP
- **App Foreground**: Checks for permission changes when app enters foreground

### Cookie API

#### Get Individual Permission Cookie:
```swift
let locationStatus = PermissionManager.shared.getPermissionCookie(for: .location)
// Returns "yes" or "no"
```

#### Get All Permission Cookies:
```swift
let allCookies = PermissionManager.shared.getAllPermissionCookies()
// Returns: ["p_Location": "yes", "p_Camera": "no", "p_Notification": "yes"]
```

#### Force Update All Cookies:
```swift
PermissionManager.shared.forceUpdatePermissionCookies()
```

#### Log Permission Summary:
```swift
PermissionManager.shared.logPermissionSummary()
```

## 🔧 How It Works

### 1. App Startup Flow
```
App Launch → Splash → Connectivity → Permissions → Main WebView
```

### 2. Permission Injection
When the WebView loads, permissions are automatically injected:

```javascript
window.zooboxPermissions = {
    "location": "granted",
    "camera": "granted", 
    "notifications": "granted"
};
```

### 3. WebView Permission Requests
When the WebView needs a permission:

1. **Check if already granted** → Use immediately
2. **If not granted** → Show explanation and request
3. **If denied** → Guide to Settings

## 📱 JavaScript API

### Available Functions

#### `window.ZooboxBridge.requestPermission(type)`
Request a specific permission with explanation.

```javascript
// Request location permission
window.ZooboxBridge.requestPermission('location');

// Request camera permission  
window.ZooboxBridge.requestPermission('camera');
```

#### `window.ZooboxBridge.isPermissionGranted(type)`
Check if a permission is already granted.

```javascript
if (window.ZooboxBridge.isPermissionGranted('location')) {
    // Permission granted, use location
    getCurrentLocation();
} else {
    // Request permission
    window.ZooboxBridge.requestPermission('location');
}
```

#### `window.ZooboxBridge.getCurrentLocation()`
Get current location if permission is granted.

```javascript
if (window.ZooboxBridge.isPermissionGranted('location')) {
    window.ZooboxBridge.getCurrentLocation();
}
```

#### `window.ZooboxBridge.hapticFeedback(type)`
Provide haptic feedback.

```javascript
window.ZooboxBridge.hapticFeedback('light');   // light, medium, heavy
```

### Permission Status Object

```javascript
window.zooboxPermissions = {
    "location": "granted",        // granted, denied, notDetermined, restricted
    "camera": "granted",
    "notifications": "granted"
};
```

### Permission Update Events

Listen for permission changes:

```javascript
window.addEventListener('zooboxPermissionsUpdate', function(event) {
    console.log('Permissions updated:', event.detail);
    
    if (event.detail.location === 'granted') {
        // Location permission was just granted
        getCurrentLocation();
    }
});
```

## 🎨 Usage Examples

### Example 1: Location Access
```javascript
function getLocation() {
    if (window.ZooboxBridge.isPermissionGranted('location')) {
        // Permission granted, get location
        window.ZooboxBridge.getCurrentLocation();
    } else {
        // Request permission with explanation
        window.ZooboxBridge.requestPermission('location');
    }
}
```

### Example 2: Camera Access
```javascript
function capturePhoto() {
    if (window.ZooboxBridge.isPermissionGranted('camera')) {
        // Permission granted, open camera
        openCameraPicker();
    } else {
        // Request permission with explanation
        window.ZooboxBridge.requestPermission('camera');
    }
}
```

### Example 3: Check All Permissions
```javascript
function checkPermissions() {
    const permissions = window.zooboxPermissions;
    
    console.log('Location:', permissions.location);
    console.log('Camera:', permissions.camera);
    console.log('Notifications:', permissions.notifications);
}
```

### Example 4: React to Permission Changes
```javascript
window.addEventListener('zooboxPermissionsUpdate', function(event) {
    const permissions = event.detail;
    
    // Update UI based on permissions
    updateLocationButton(permissions.location === 'granted');
    updateCameraButton(permissions.camera === 'granted');
    updateNotificationButton(permissions.notifications === 'granted');
});
```

## 🔍 Debug Features

### Console Logging
The system provides detailed console logging:

```
🔐 ZooboxBridge initialized
🔐 Available permissions: {location: "granted", camera: "granted", ...}
🔐 WebView requesting permission: Location
🔐 Permission status for Location: granted
```

### Debug Button
The PermissionViewController includes a debug button that shows:
- Current permission status
- Permission request history
- Settings access

## 🛠️ Implementation Details

### Permission Types
```swift
enum PermissionType: String, CaseIterable {
    case location = "location"
    case camera = "camera" 
    case notifications = "notifications"
}
```

### Permission Status
```swift
enum PermissionStatus: String {
    case notDetermined = "notDetermined"
    case denied = "denied"
    case restricted = "restricted"
    case granted = "granted"
}
```

### WebView Integration
The system automatically:
1. Injects permissions when WebView loads
2. Handles permission requests from JavaScript
3. Updates permissions in real-time
4. Provides haptic feedback

## 🚀 Benefits

### For Users
- ✅ No duplicate permission dialogs
- ✅ Clear explanations of why permissions are needed
- ✅ Seamless experience across app and web
- ✅ Easy access to Settings when needed

### For Developers
- ✅ Centralized permission management
- ✅ Consistent permission handling
- ✅ Real-time permission updates
- ✅ Comprehensive JavaScript API
- ✅ Detailed debugging tools

### For Web Content
- ✅ Automatic access to granted permissions
- ✅ Smart permission requests with explanations
- ✅ Real-time permission status updates
- ✅ Haptic feedback integration

## 📋 Testing

### Test Scenarios
1. **Fresh Install**: All permissions should be requested with explanations
2. **Granted Permissions**: WebView should use permissions without asking
3. **Denied Permissions**: Should guide to Settings
4. **Permission Changes**: WebView should update in real-time
5. **Multiple Requests**: Should handle multiple permission requests gracefully

### Debug Tools
- Use the debug button in PermissionViewController
- Check console logs for detailed information
- Monitor permission status in real-time

## 🔧 Configuration

### Info.plist Requirements
Make sure these keys are present:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Zoobox needs your location to show nearby services and enable deliveries.</string>
<key>NSCameraUsageDescription</key>
<string>Zoobox needs camera access to scan QR codes and upload documents.</string>
<key>NSUserNotificationUsageDescription</key>
<string>Zoobox uses notifications to update you about orders and deliveries.</string>
```

## 📚 Additional Resources

- **JavaScript Examples**: See `webview-permissions-example.js`
- **Permission Flow**: Check `PermissionViewController.swift`
- **WebView Integration**: See `MainViewController.swift`
- **Core Logic**: Review `PermissionManager.swift`

---

**🎉 The Zoobox permission system provides a seamless, user-friendly experience that respects user choices while ensuring the app has the permissions it needs to function properly.** 