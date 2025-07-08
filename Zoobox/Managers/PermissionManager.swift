import UIKit
import CoreLocation
import AVFoundation
import UserNotifications
import WebKit

protocol PermissionManagerDelegate: AnyObject {
    func permissionManager(_ manager: PermissionManager, didUpdatePermissions permissions: [PermissionType: PermissionStatus])
    func permissionManager(_ manager: PermissionManager, requiresPermissionAlertFor permission: PermissionType)
}

enum PermissionType: String, CaseIterable {
    case location = "location"
    case camera = "camera"
    case notifications = "notifications"
    
    var displayName: String {
        switch self {
        case .location: return "Location"
        case .camera: return "Camera"
        case .notifications: return "Notifications"
        }
    }
    
    var usageDescription: String {
        switch self {
        case .location: return "Zoobox needs your location to show nearby services and enable deliveries."
        case .camera: return "Zoobox needs camera access to scan QR codes and upload documents."
        case .notifications: return "Zoobox uses notifications to update you about orders and deliveries."
        }
    }
}

enum PermissionStatus: String {
    case notDetermined = "notDetermined"
    case denied = "denied"
    case restricted = "restricted"
    case granted = "granted"
    
    var isGranted: Bool {
        return self == .granted
    }
}

class PermissionManager: NSObject {
    static let shared = PermissionManager()
    
    weak var delegate: PermissionManagerDelegate?
    private let locationManager = CLLocationManager()
    
    private var permissionStatuses: [PermissionType: PermissionStatus] = [:]
    private var permissionAlertsShown: [PermissionType: Bool] = [:]
    
    // MARK: - Permission Cookie Keys
    private struct PermissionCookieKeys {
        static let location = "p_Location"
        static let camera = "p_Camera"
        static let notification = "p_Notification"
    }
    
    override init() {
        super.init()
        setupLocationManager()
        initializePermissionCookies()
        updateAllPermissionStatuses()
        setupAppStateObservers()
    }
    
    deinit {
        // Clean up observers
        NotificationCenter.default.removeObserver(self)
        print("🍪 [PermissionManager] Permission observers cleaned up")
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
    }
    
    // MARK: - Permission Cookie Management
    
    private func initializePermissionCookies() {
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] INITIALIZING PERMISSION COOKIES")
        print("🍪 [PermissionManager] ========================================")
        
        // Initialize cookies for each permission type if they don't exist
        for permissionType in PermissionType.allCases {
            let cookieKey = getCookieKey(for: permissionType)
            let currentSystemStatus = getCurrentPermissionStatus(for: permissionType)
            let expectedValue = currentSystemStatus.isGranted ? "yes" : "no"
            
            // Check if cookie exists, if not create it with default "no" value
            if UserDefaults.standard.object(forKey: cookieKey) == nil {
                print("🍪 [PermissionManager] 🆕 CREATING NEW COOKIE:")
                print("🍪 [PermissionManager]    Key: \(cookieKey)")
                print("🍪 [PermissionManager]    Initial Value: no")
                print("🍪 [PermissionManager]    System Status: \(currentSystemStatus.rawValue)")
                print("🍪 [PermissionManager]    Expected Value: \(expectedValue)")
                UserDefaults.standard.set("no", forKey: cookieKey)
            } else {
                let currentValue = UserDefaults.standard.string(forKey: cookieKey) ?? "no"
                print("🍪 [PermissionManager] 📋 EXISTING COOKIE FOUND:")
                print("🍪 [PermissionManager]    Key: \(cookieKey)")
                print("🍪 [PermissionManager]    Current Value: \(currentValue)")
                print("🍪 [PermissionManager]    System Status: \(currentSystemStatus.rawValue)")
                print("🍪 [PermissionManager]    Expected Value: \(expectedValue)")
                
                // Check if cookie value matches system status
                if currentValue != expectedValue {
                    print("🍪 [PermissionManager] ⚠️  COOKIE MISMATCH DETECTED!")
                    print("🍪 [PermissionManager]    Will be updated to match system status")
                }
            }
        }
        
        UserDefaults.standard.synchronize()
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] PERMISSION COOKIES INITIALIZATION COMPLETE")
        print("🍪 [PermissionManager] ========================================")
    }
    
    private func getCookieKey(for type: PermissionType) -> String {
        switch type {
        case .location: return PermissionCookieKeys.location
        case .camera: return PermissionCookieKeys.camera
        case .notifications: return PermissionCookieKeys.notification
        }
    }
    
    private func updatePermissionCookie(for type: PermissionType, status: PermissionStatus) {
        let cookieKey = getCookieKey(for: type)
        let newCookieValue = status.isGranted ? "yes" : "no"
        let oldCookieValue = UserDefaults.standard.string(forKey: cookieKey) ?? "no"
        
        // Only update and log if value actually changed
        if oldCookieValue != newCookieValue {
            print("🍪 [PermissionManager] 🔄 COOKIE UPDATE DETECTED:")
            print("🍪 [PermissionManager]    Permission: \(type.displayName)")
            print("🍪 [PermissionManager]    Cookie Key: \(cookieKey)")
            print("🍪 [PermissionManager]    Old Value: \(oldCookieValue)")
            print("🍪 [PermissionManager]    New Value: \(newCookieValue)")
            print("🍪 [PermissionManager]    Status: \(status.rawValue)")
            print("🍪 [PermissionManager]    Change: \(oldCookieValue) → \(newCookieValue)")
            
            UserDefaults.standard.set(newCookieValue, forKey: cookieKey)
            UserDefaults.standard.synchronize()
            
            print("🍪 [PermissionManager] ✅ Cookie successfully updated and synchronized")
        } else {
            print("🍪 [PermissionManager] 📌 Cookie already up-to-date:")
            print("🍪 [PermissionManager]    Permission: \(type.displayName)")
            print("🍪 [PermissionManager]    Cookie Key: \(cookieKey)")
            print("🍪 [PermissionManager]    Value: \(newCookieValue)")
            print("🍪 [PermissionManager]    Status: \(status.rawValue)")
        }
    }
    
    private func updateAllPermissionCookies() {
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] UPDATING ALL PERMISSION COOKIES")
        print("🍪 [PermissionManager] ========================================")
        
        for permissionType in PermissionType.allCases {
            let currentStatus = getCurrentPermissionStatus(for: permissionType)
            print("🍪 [PermissionManager] 🔍 Checking \(permissionType.displayName) permission:")
            print("🍪 [PermissionManager]    System Status: \(currentStatus.rawValue)")
            updatePermissionCookie(for: permissionType, status: currentStatus)
        }
        
        print("🍪 [PermissionManager] 📱 Checking notification permission asynchronously...")
        
        // Also update notification status asynchronously
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                let notificationStatus: PermissionStatus
                switch settings.authorizationStatus {
                case .notDetermined: notificationStatus = .notDetermined
                case .denied: notificationStatus = .denied
                case .authorized, .provisional, .ephemeral: notificationStatus = .granted
                @unknown default: notificationStatus = .notDetermined
                }
                
                print("🍪 [PermissionManager] 📱 Notification permission status received:")
                print("🍪 [PermissionManager]    Authorization Status: \(settings.authorizationStatus)")
                print("🍪 [PermissionManager]    Mapped Status: \(notificationStatus.rawValue)")
                
                self?.updatePermissionCookie(for: .notifications, status: notificationStatus)
                
                print("🍪 [PermissionManager] ========================================")
                print("🍪 [PermissionManager] ALL PERMISSION COOKIES UPDATE COMPLETE")
                print("🍪 [PermissionManager] ========================================")
            }
        }
    }
    
    private func setupAppStateObservers() {
        print("🍪 [PermissionManager] Setting up app state observers for permission tracking")
        
        // Observer for when app becomes active (user returns from Settings)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Observer for when app enters foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 📱 APP BECAME ACTIVE")
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 🔍 User may have returned from Settings...")
        print("🍪 [PermissionManager] 🔄 Checking for permission changes...")
        
        // Get current cookie states before update
        let beforeCookies = getAllPermissionCookies()
        print("🍪 [PermissionManager] 📊 Cookie state before update:")
        for (key, value) in beforeCookies {
            print("🍪 [PermissionManager]    \(key): \(value)")
        }
        
        // Check and update all permissions when app becomes active
        // This catches changes made in Settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🍪 [PermissionManager] ⏰ 0.5s delay completed - updating permissions...")
            self.updateAllPermissionStatuses()
            self.updateAllPermissionCookies()
            
            // Show cookie states after update
            let afterCookies = self.getAllPermissionCookies()
            print("🍪 [PermissionManager] 📊 Cookie state after update:")
            for (key, value) in afterCookies {
                print("🍪 [PermissionManager]    \(key): \(value)")
            }
            
            // Check for changes
            var changesDetected = false
            for (key, newValue) in afterCookies {
                if let oldValue = beforeCookies[key], oldValue != newValue {
                    print("🍪 [PermissionManager] 🔥 CHANGE DETECTED: \(key) changed from \(oldValue) to \(newValue)")
                    changesDetected = true
                }
            }
            
            if !changesDetected {
                print("🍪 [PermissionManager] 📌 No permission changes detected")
            }
        }
    }
    
    @objc private func appWillEnterForeground() {
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 🌅 APP ENTERING FOREGROUND")
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 🔄 Updating permission statuses...")
        
        // Get current cookie states before update
        let beforeCookies = getAllPermissionCookies()
        print("🍪 [PermissionManager] 📊 Cookie state before foreground update:")
        for (key, value) in beforeCookies {
            print("🍪 [PermissionManager]    \(key): \(value)")
        }
        
        // Update permissions when app enters foreground
        updateAllPermissionStatuses()
        updateAllPermissionCookies()
        
        // Show cookie states after update
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let afterCookies = self.getAllPermissionCookies()
            print("🍪 [PermissionManager] 📊 Cookie state after foreground update:")
            for (key, value) in afterCookies {
                print("🍪 [PermissionManager]    \(key): \(value)")
            }
        }
    }
    
    // MARK: - Public Cookie Methods
    
    /// Get the current cookie value for a permission type
    func getPermissionCookie(for type: PermissionType) -> String {
        let cookieKey = getCookieKey(for: type)
        let cookieValue = UserDefaults.standard.string(forKey: cookieKey) ?? "no"
        print("🍪 [PermissionManager] 🔍 Cookie accessed: \(cookieKey) = \(cookieValue)")
        return cookieValue
    }
    
    /// Get all permission cookies as a dictionary
    func getAllPermissionCookies() -> [String: String] {
        print("🍪 [PermissionManager] 📋 Getting all permission cookies...")
        var cookies: [String: String] = [:]
        
        for permissionType in PermissionType.allCases {
            let cookieKey = getCookieKey(for: permissionType)
            let cookieValue = UserDefaults.standard.string(forKey: cookieKey) ?? "no"
            cookies[cookieKey] = cookieValue
            print("🍪 [PermissionManager]    \(cookieKey): \(cookieValue)")
        }
        
        print("🍪 [PermissionManager] ✅ All cookies retrieved")
        return cookies
    }
    
    /// Force update all permission cookies based on current system permissions
    func forceUpdatePermissionCookies() {
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 🔄 FORCE UPDATE ALL PERMISSION COOKIES")
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 💪 Manual force update requested...")
        updateAllPermissionCookies()
    }
    
    /// Log current permission and cookie state summary
    func logPermissionSummary() {
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 📊 PERMISSION SUMMARY")
        print("🍪 [PermissionManager] ========================================")
        
        for permissionType in PermissionType.allCases {
            let systemStatus = getCurrentPermissionStatus(for: permissionType)
            let cookieKey = getCookieKey(for: permissionType)
            let cookieValue = UserDefaults.standard.string(forKey: cookieKey) ?? "no"
            let isInSync = (systemStatus.isGranted ? "yes" : "no") == cookieValue
            
            print("🍪 [PermissionManager] 📋 \(permissionType.displayName):")
            print("🍪 [PermissionManager]    System Status: \(systemStatus.rawValue)")
            print("🍪 [PermissionManager]    Cookie Key: \(cookieKey)")
            print("🍪 [PermissionManager]    Cookie Value: \(cookieValue)")
            print("🍪 [PermissionManager]    In Sync: \(isInSync ? "✅" : "❌")")
            
            if !isInSync {
                print("🍪 [PermissionManager]    ⚠️  MISMATCH DETECTED!")
            }
            print("🍪 [PermissionManager]    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
        
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 📊 SUMMARY COMPLETE")
        print("🍪 [PermissionManager] ========================================")
    }
    
    // MARK: - Public Methods
    
    func getPermissionStatus(for type: PermissionType) -> PermissionStatus {
        return permissionStatuses[type] ?? .notDetermined
    }
    
    func isPermissionGranted(for type: PermissionType) -> Bool {
        return getPermissionStatus(for: type).isGranted
    }
    
    func requestPermission(for type: PermissionType, from viewController: UIViewController? = nil) {
        let currentStatus = getPermissionStatus(for: type)
        
        switch currentStatus {
        case .notDetermined:
            requestPermissionDirectly(for: type)
        case .denied, .restricted:
            showPermissionDeniedAlert(for: type, from: viewController)
        case .granted:
            // Already granted, no action needed
            break
        }
    }
    
    func requestPermissionWithExplanation(for type: PermissionType, from viewController: UIViewController) {
        let currentStatus = getPermissionStatus(for: type)
        
        switch currentStatus {
        case .notDetermined:
            showPrePermissionAlert(for: type, from: viewController)
        case .denied, .restricted:
            showPermissionDeniedAlert(for: type, from: viewController)
        case .granted:
            // Already granted, no action needed
            break
        }
    }
    
    func updateAllPermissionStatuses() {
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 📊 UPDATING ALL PERMISSION STATUSES")
        print("🍪 [PermissionManager] ========================================")
        
        // Update location and camera synchronously
        let locationStatus = getCurrentPermissionStatus(for: .location)
        let cameraStatus = getCurrentPermissionStatus(for: .camera)
        
        print("🍪 [PermissionManager] 🔄 Synchronous permissions check:")
        print("🍪 [PermissionManager]    Location: \(locationStatus.rawValue)")
        print("🍪 [PermissionManager]    Camera: \(cameraStatus.rawValue)")
        
        permissionStatuses[.location] = locationStatus
        permissionStatuses[.camera] = cameraStatus
        
        // Update cookies for synchronous permissions
        updatePermissionCookie(for: .location, status: locationStatus)
        updatePermissionCookie(for: .camera, status: cameraStatus)
        
        print("🍪 [PermissionManager] 🔄 Checking notifications asynchronously...")
        
        // Update notification status asynchronously
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                let notificationStatus: PermissionStatus
                switch settings.authorizationStatus {
                case .notDetermined: notificationStatus = .notDetermined
                case .denied: notificationStatus = .denied
                case .authorized, .provisional, .ephemeral: notificationStatus = .granted
                @unknown default: notificationStatus = .notDetermined
                }
                
                print("🍪 [PermissionManager] 🔄 Asynchronous notification check complete:")
                print("🍪 [PermissionManager]    Notifications: \(notificationStatus.rawValue)")
                
                self?.permissionStatuses[.notifications] = notificationStatus
                self?.updatePermissionCookie(for: .notifications, status: notificationStatus)
                self?.notifyDelegateOfPermissionChanges()
                
                print("🍪 [PermissionManager] ========================================")
                print("🍪 [PermissionManager] ✅ ALL PERMISSION STATUSES UPDATED")
                print("🍪 [PermissionManager] ========================================")
            }
        }
    }
    
    // MARK: - WebView Integration
    
    func injectPermissionStatusToWebView(_ webView: WKWebView) {
        // DISABLED: JavaScript evaluation disabled to prevent EXC_BAD_ACCESS crashes
        print("🔐 [PermissionManager] DISABLED: Permission injection disabled to prevent EXC_BAD_ACCESS crashes")
        print("🔐 [PermissionManager] DISABLED: Use native iOS permission APIs instead")
        
        let permissionData: [String: Any] = Dictionary(uniqueKeysWithValues: PermissionType.allCases.map { type in
            (type.rawValue, getPermissionStatus(for: type).rawValue)
        })
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: permissionData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🔐 [PermissionManager] DISABLED: Would have injected: \(jsonString)")
        }
        
        /* DISABLED CODE THAT WAS CAUSING EXC_BAD_ACCESS CRASHES:
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: permissionData),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let jsCode = """
            // Update the permissions object
            window.zooboxPermissions = \(jsonString);
            
            // Dispatch permission update event
            window.dispatchEvent(new CustomEvent('zooboxPermissionsUpdate', {
                detail: \(jsonString)
            }));
            
            console.log('🔐 Zoobox permissions injected:', \(jsonString));
            console.log('🔐 Current permissions object:', window.zooboxPermissions);
        """
        
        webView.evaluateJavaScript(jsCode) { _, error in
            if let error = error {
                print("🔐 Error injecting permissions: \(error)")
            } else {
                print("🔐 Permissions injected successfully: \(jsonString)")
            }
        }
        
        */
    }
    
    func forceRefreshPermissionsInWebView(_ webView: WKWebView) {
        // DISABLED: JavaScript evaluation disabled to prevent EXC_BAD_ACCESS crashes
        print("🔐 [PermissionManager] DISABLED: Permission refresh disabled to prevent EXC_BAD_ACCESS crashes")
        print("🔐 [PermissionManager] DISABLED: Use native iOS permission APIs instead")
        
        // Force a complete refresh of permissions in the webview
        let permissionData: [String: Any] = Dictionary(uniqueKeysWithValues: PermissionType.allCases.map { type in
            (type.rawValue, getPermissionStatus(for: type).rawValue)
        })
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: permissionData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🔐 [PermissionManager] DISABLED: Would have refreshed: \(jsonString)")
        }
        
        /* DISABLED CODE THAT WAS CAUSING EXC_BAD_ACCESS CRASHES:
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: permissionData),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let jsCode = """
            // Force refresh permissions
            window.zooboxPermissions = \(jsonString);
            
            // Force dispatch multiple events to ensure it's caught
            window.dispatchEvent(new CustomEvent('zooboxPermissionsUpdate', {
                detail: \(jsonString)
            }));
            
            // Also trigger a custom event for immediate update
            window.dispatchEvent(new CustomEvent('zooboxPermissionsForceUpdate', {
                detail: \(jsonString)
            }));
            
            console.log('🔐 Permissions force refreshed:', \(jsonString));
            
            // Notify any waiting callbacks
            if (window.onZooboxPermissionUpdate) {
                window.onZooboxPermissionUpdate(\(jsonString));
            }
        """
        
        webView.evaluateJavaScript(jsCode) { _, error in
            if let error = error {
                print("🔐 Error force refreshing permissions: \(error)")
            } else {
                print("🔐 Permissions force refreshed successfully")
            }
        }
        
        */
    }
    
    func handleWebViewPermissionRequest(for type: PermissionType, from viewController: UIViewController) {
        if isPermissionGranted(for: type) {
            // Permission already granted, allow access
            allowWebViewAccess(for: type)
        } else {
            // Request permission with explanation
            requestPermissionWithExplanation(for: type, from: viewController)
        }
    }
    
    // MARK: - Private Methods
    
    private func getCurrentPermissionStatus(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .location:
            let status = CLLocationManager.authorizationStatus()
            switch status {
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            case .restricted: return .restricted
            case .authorizedWhenInUse, .authorizedAlways: return .granted
            @unknown default: return .notDetermined
            }
            
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            case .restricted: return .restricted
            case .authorized: return .granted
            @unknown default: return .notDetermined
            }
            
        case .notifications:
            // Return cached value, will be updated when notification permission is requested
            return permissionStatuses[.notifications] ?? .notDetermined
        }
    }
    
    func requestPermissionDirectly(for type: PermissionType) {
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 🚀 REQUESTING PERMISSION DIRECTLY")
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 🎯 Permission Type: \(type.displayName)")
        print("🍪 [PermissionManager] 🔄 Initiating permission request...")
        
        // Reset alert shown flag to allow retry
        permissionAlertsShown[type] = false
        
        switch type {
        case .location:
            print("🍪 [PermissionManager] 📍 Requesting location authorization...")
            locationManager.requestWhenInUseAuthorization()
            
        case .camera:
            print("🍪 [PermissionManager] 📷 Requesting camera access...")
            let oldStatus = permissionStatuses[.camera] ?? .notDetermined
            let oldCookieValue = getPermissionCookie(for: .camera)
            
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    print("🍪 [PermissionManager] 📷 Camera permission response received:")
                    print("🍪 [PermissionManager]    Granted: \(granted)")
                    print("🍪 [PermissionManager]    Old Status: \(oldStatus.rawValue)")
                    print("🍪 [PermissionManager]    Old Cookie: \(oldCookieValue)")
                    
                    let newStatus: PermissionStatus = granted ? .granted : .denied
                    let newCookieValue = newStatus.isGranted ? "yes" : "no"
                    
                    print("🍪 [PermissionManager]    New Status: \(newStatus.rawValue)")
                    print("🍪 [PermissionManager]    New Cookie: \(newCookieValue)")
                    
                    if oldStatus != newStatus {
                        print("🍪 [PermissionManager] 🔥 CAMERA STATUS CHANGE: \(oldStatus.rawValue) → \(newStatus.rawValue)")
                    }
                    if oldCookieValue != newCookieValue {
                        print("🍪 [PermissionManager] 🔥 CAMERA COOKIE CHANGE: \(oldCookieValue) → \(newCookieValue)")
                    }
                    
                    self?.permissionStatuses[.camera] = newStatus
                    self?.updatePermissionCookie(for: .camera, status: newStatus)
                    self?.notifyDelegateOfPermissionChanges()
                    
                    print("🍪 [PermissionManager] ✅ Camera permission processing complete")
                }
            }
            
        case .notifications:
            print("🍪 [PermissionManager] 🔔 Requesting notification authorization...")
            let oldStatus = permissionStatuses[.notifications] ?? .notDetermined
            let oldCookieValue = getPermissionCookie(for: .notifications)
            
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    print("🍪 [PermissionManager] 🔔 Notification permission response received:")
                    print("🍪 [PermissionManager]    Granted: \(granted)")
                    print("🍪 [PermissionManager]    Old Status: \(oldStatus.rawValue)")
                    print("🍪 [PermissionManager]    Old Cookie: \(oldCookieValue)")
                    
                    let newStatus: PermissionStatus = granted ? .granted : .denied
                    let newCookieValue = newStatus.isGranted ? "yes" : "no"
                    
                    print("🍪 [PermissionManager]    New Status: \(newStatus.rawValue)")
                    print("🍪 [PermissionManager]    New Cookie: \(newCookieValue)")
                    
                    if oldStatus != newStatus {
                        print("🍪 [PermissionManager] 🔥 NOTIFICATION STATUS CHANGE: \(oldStatus.rawValue) → \(newStatus.rawValue)")
                    }
                    if oldCookieValue != newCookieValue {
                        print("🍪 [PermissionManager] 🔥 NOTIFICATION COOKIE CHANGE: \(oldCookieValue) → \(newCookieValue)")
                    }
                    
                    self?.permissionStatuses[.notifications] = newStatus
                    self?.updatePermissionCookie(for: .notifications, status: newStatus)
                    self?.notifyDelegateOfPermissionChanges()
                    
                    print("🍪 [PermissionManager] ✅ Notification permission processing complete")
                }
            }
        }
    }
    
    private func showPrePermissionAlert(for type: PermissionType, from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "\(type.displayName) Access Needed",
            message: type.usageDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in
            self.requestPermissionDirectly(for: type)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        viewController.present(alert, animated: true)
    }
    
    private func showPermissionDeniedAlert(for type: PermissionType, from viewController: UIViewController?) {
        guard !(permissionAlertsShown[type] ?? false) else { return }
        permissionAlertsShown[type] = true
        
        let alert = UIAlertController(
            title: "\(type.displayName) Permission",
            message: "\(type.displayName) access helps improve your experience but is not required. You can enable it in Settings or continue without it.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Continue Anyway", style: .default) { _ in
            // Continue without this permission
            self.permissionAlertsShown[type] = false
        })
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        if let vc = viewController {
            // iPad-specific popover presentation
            if UIDevice.current.isIPad {
                if let popover = alert.popoverPresentationController {
                    popover.sourceView = vc.view
                    popover.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
            }
            vc.present(alert, animated: true)
        } else {
            delegate?.permissionManager(self, requiresPermissionAlertFor: type)
        }
    }
    
    private func allowWebViewAccess(for type: PermissionType) {
        // This method can be used to inject permission status or handle WebView access
        print("🔐 Allowing WebView access for \(type.displayName)")
    }
    
    private func notifyDelegateOfPermissionChanges() {
        delegate?.permissionManager(self, didUpdatePermissions: permissionStatuses)
    }
    
    func resetPermissionAlerts() {
        permissionAlertsShown.removeAll()
    }
    
    func canRetryPermission(for type: PermissionType) -> Bool {
        let status = getPermissionStatus(for: type)
        return status == .denied || status == .notDetermined
    }
    
    func areAllPermissionsGranted() -> Bool {
        return PermissionType.allCases.allSatisfy { isPermissionGranted(for: $0) }
    }
    
    func getDeniedPermissions() -> [PermissionType] {
        return PermissionType.allCases.filter { getPermissionStatus(for: $0) == .denied }
    }
    
    func getNotDeterminedPermissions() -> [PermissionType] {
        return PermissionType.allCases.filter { getPermissionStatus(for: $0) == .notDetermined }
    }
}

// MARK: - CLLocationManagerDelegate
extension PermissionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🍪 [PermissionManager] ========================================")
        print("🍪 [PermissionManager] 📍 LOCATION PERMISSION CHANGE DETECTED")
        print("🍪 [PermissionManager] ========================================")
        
        let oldStatus = permissionStatuses[.location] ?? .notDetermined
        let oldCookieValue = getPermissionCookie(for: .location)
        
        let newStatus: PermissionStatus
        switch status {
        case .notDetermined: newStatus = .notDetermined
        case .denied: newStatus = .denied
        case .restricted: newStatus = .restricted
        case .authorizedWhenInUse, .authorizedAlways: newStatus = .granted
        @unknown default: newStatus = .notDetermined
        }
        
        let newCookieValue = newStatus.isGranted ? "yes" : "no"
        
        print("🍪 [PermissionManager] 📍 Location Permission Details:")
        print("🍪 [PermissionManager]    CLAuthorizationStatus: \(status.rawValue)")
        print("🍪 [PermissionManager]    Old Status: \(oldStatus.rawValue)")
        print("🍪 [PermissionManager]    New Status: \(newStatus.rawValue)")
        print("🍪 [PermissionManager]    Old Cookie: \(oldCookieValue)")
        print("🍪 [PermissionManager]    New Cookie: \(newCookieValue)")
        
        if oldStatus != newStatus {
            print("🍪 [PermissionManager] 🔥 STATUS CHANGE: \(oldStatus.rawValue) → \(newStatus.rawValue)")
        } else {
            print("🍪 [PermissionManager] 📌 Status unchanged: \(newStatus.rawValue)")
        }
        
        if oldCookieValue != newCookieValue {
            print("🍪 [PermissionManager] 🔥 COOKIE CHANGE: \(oldCookieValue) → \(newCookieValue)")
        } else {
            print("🍪 [PermissionManager] 📌 Cookie unchanged: \(newCookieValue)")
        }
        
        permissionStatuses[.location] = newStatus
        updatePermissionCookie(for: .location, status: newStatus)
        notifyDelegateOfPermissionChanges()
        
        print("🍪 [PermissionManager] ✅ Location permission processing complete")
    }
} 