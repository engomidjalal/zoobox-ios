# 🍪 Cookie Persistence System Documentation

## Overview

The Zoobox app now includes a robust cookie persistence system that ensures cookies survive app updates, device reboots, and other scenarios where WebView cookies might be cleared.

## 🔧 Implementation Details

### CookieManager Class

The `CookieManager` class handles all cookie-related operations:

```swift
class CookieManager: NSObject {
    static let shared = CookieManager()
    
    // Backup cookies to UserDefaults
    func backupCookies(from webView: WKWebView)
    
    // Restore cookies from UserDefaults to WebView
    func restoreCookies(to webView: WKWebView)
    
    // Clear backup cookies
    func clearBackupCookies()
    
    // Get backup cookie count
    func getBackupCookieCount() -> Int
    
    // Check if backup is needed
    func shouldBackupCookies() -> Bool
}
```

### Key Features

#### 1. **Automatic Backup**
- Cookies are automatically backed up after each page load
- Backup occurs when app goes to background or terminates
- Backup interval: Every 1 hour (configurable)

#### 2. **Automatic Restoration**
- Cookies are restored when the app starts
- Restoration happens before loading the main site
- Ensures seamless user experience

#### 3. **Expiry Management**
- Expired cookies are automatically cleaned up
- Prevents accumulation of invalid cookies
- Maintains optimal performance

#### 4. **Comprehensive Cookie Properties**
The system preserves all cookie properties:
- Name, value, domain, path
- Expiration date
- Secure flag
- HTTP-only flag
- Comments and URLs
- Port lists
- Version information

## 📱 Integration Points

### MainViewController Integration

```swift
// Setup
private func setupCookieManager() {
    cookieManager.delegate = self
}

// Restore cookies on app start
private func loadMainSite() {
    webView.restoreCookies()
    // ... load site
}

// Backup cookies after page load
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    if cookieManager.shouldBackupCookies() {
        webView.backupCookies()
    }
    // ... other operations
}
```

### AppDelegate Integration

```swift
func applicationWillTerminate(_ application: UIApplication) {
    // CookieManager handles backup automatically via notifications
}

func applicationDidEnterBackground(_ application: UIApplication) {
    // CookieManager handles backup automatically via notifications
}
```

### Settings Integration

The Settings screen now shows:
- Number of saved cookies
- Cookie backup status
- Last backup timestamp

## 🔄 Persistence Scenarios

### ✅ **Survives These Scenarios:**

1. **App Restarts**: ✅ Permanent
   - Cookies restored from UserDefaults
   - No data loss

2. **Device Reboots**: ✅ Permanent
   - UserDefaults persist across reboots
   - Cookies automatically restored

3. **App Updates**: ✅ Permanent
   - UserDefaults survive app updates
   - Cookies restored after update

4. **Background/Foreground**: ✅ Permanent
   - Automatic backup when going to background
   - Automatic restoration when becoming active

5. **Memory Pressure**: ✅ Permanent
   - Cookies backed up to persistent storage
   - Not affected by memory cleanup

### ❌ **Does Not Survive:**

1. **App Deletion**: ❌ Lost
   - UserDefaults cleared when app is deleted
   - This is normal iOS behavior

2. **Device Reset**: ❌ Lost
   - All app data cleared
   - This is normal iOS behavior

## 📊 Performance Considerations

### Storage Efficiency
- Cookies are stored as JSON in UserDefaults
- Minimal storage overhead
- Automatic cleanup of expired cookies

### Backup Frequency
- Default: Every 1 hour
- Configurable via `backupInterval`
- Prevents excessive UserDefaults writes

### Memory Usage
- Cookies loaded on-demand
- No persistent memory overhead
- Efficient serialization/deserialization

## 🛠️ Usage Examples

### Manual Cookie Operations

```swift
// Backup cookies manually
webView.backupCookies()

// Restore cookies manually
webView.restoreCookies()

// Clear backup cookies
CookieManager.shared.clearBackupCookies()

// Check backup status
let count = CookieManager.shared.getBackupCookieCount()
let lastBackup = CookieManager.shared.getLastBackupDate()
```

### WKWebView Extensions

```swift
// Convenience methods added to WKWebView
webView.backupCookies()
webView.restoreCookies()
webView.cleanupExpiredCookies()
```

## 🔍 Debugging and Monitoring

### Console Logs
The system provides detailed logging:
```
🍪 Backed up 5 cookies to UserDefaults
🍪 Restored 5 cookies to WebView
🍪 Cleaned up 2 expired cookies
🍪 App will terminate - backing up cookies
```

### Settings Screen
- Real-time cookie count display
- Backup status information
- Last backup timestamp

### Error Handling
- Comprehensive error handling
- Graceful fallbacks
- Detailed error logging

## 🚀 Best Practices

### 1. **Automatic Operation**
- Let the system handle cookies automatically
- Manual intervention rarely needed

### 2. **Monitoring**
- Check Settings screen for cookie status
- Monitor console logs for issues

### 3. **Testing**
- Test with app updates
- Test with device reboots
- Test with various cookie types

### 4. **Maintenance**
- System automatically cleans expired cookies
- No manual maintenance required

## 🔧 Configuration

### Backup Interval
```swift
private let backupInterval: TimeInterval = 3600 // 1 hour
```

### Storage Keys
```swift
private let cookieBackupKey = "backupCookies"
private let lastBackupKey = "lastCookieBackup"
```

### Maximum Cookie Properties
The system preserves all standard HTTP cookie properties:
- Basic: name, value, domain, path
- Security: secure, httpOnly
- Metadata: comments, URLs, ports, version
- Timing: expiration dates

## 📈 Benefits

### For Users
- Seamless experience across app updates
- No need to re-login after updates
- Persistent session state
- Faster app startup

### For Developers
- Robust cookie management
- Automatic handling of edge cases
- Comprehensive error handling
- Easy debugging and monitoring

### For App Performance
- Minimal storage overhead
- Efficient backup/restore operations
- Automatic cleanup of expired data
- No impact on app startup time

## 🔮 Future Enhancements

### Potential Improvements
1. **Encrypted Storage**: Add encryption for sensitive cookies
2. **Selective Backup**: Allow users to choose which cookies to backup
3. **Cloud Sync**: Sync cookies across devices
4. **Advanced Analytics**: Detailed cookie usage statistics
5. **Custom Expiry**: User-configurable cookie retention policies

### Monitoring Features
1. **Cookie Analytics**: Track cookie usage patterns
2. **Performance Metrics**: Monitor backup/restore performance
3. **Error Reporting**: Enhanced error tracking and reporting
4. **User Notifications**: Notify users of cookie-related issues

---

*This documentation covers the complete cookie persistence system implemented in Zoobox. The system ensures reliable cookie management across all app lifecycle events and provides a seamless user experience.* 