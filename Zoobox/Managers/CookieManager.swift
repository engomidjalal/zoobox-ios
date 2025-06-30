import Foundation
import WebKit

protocol CookieManagerDelegate: AnyObject {
    func cookieManager(_ manager: CookieManager, didSaveCookies count: Int)
    func cookieManager(_ manager: CookieManager, didRestoreCookies count: Int)
    func cookieManager(_ manager: CookieManager, didEncounterError error: Error)
}

class CookieManager: NSObject {
    static let shared = CookieManager()
    
    weak var delegate: CookieManagerDelegate?
    
    private let userDefaults = UserDefaults.standard
    private let cookieBackupKey = "backupCookies"
    private let lastBackupKey = "lastCookieBackup"
    private let backupInterval: TimeInterval = 300 // 5 minutes (reduced from 1 hour)
    
    private var isBackingUp = false
    private var isRestoring = false
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    // MARK: - Public Methods
    
    func backupCookies(from webView: WKWebView) {
        guard !isBackingUp else { return }
        isBackingUp = true
        
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.saveCookiesToUserDefaults(cookies)
                self.isBackingUp = false
            }
        }
    }
    
    func restoreCookies(to webView: WKWebView) {
        guard !isRestoring else { return }
        isRestoring = true
        
        guard let cookieData = userDefaults.array(forKey: cookieBackupKey) as? [[String: Any]] else {
            isRestoring = false
            return
        }
        
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        var restoredCount = 0
        let group = DispatchGroup()
        
        for cookieInfo in cookieData {
            group.enter()
            
            if let cookie = createCookie(from: cookieInfo) {
                cookieStore.setCookie(cookie) {
                    restoredCount += 1
                    group.leave()
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            self.delegate?.cookieManager(self, didRestoreCookies: restoredCount)
            self.isRestoring = false
            
            print("🍪 Restored \(restoredCount) cookies to WebView")
        }
    }
    
    func clearBackupCookies() {
        userDefaults.removeObject(forKey: cookieBackupKey)
        userDefaults.removeObject(forKey: lastBackupKey)
        print("🍪 Cleared backup cookies")
    }
    
    func getBackupCookieCount() -> Int {
        guard let cookieData = userDefaults.array(forKey: cookieBackupKey) as? [[String: Any]] else {
            return 0
        }
        return cookieData.count
    }
    
    func getLastBackupDate() -> Date? {
        return userDefaults.object(forKey: lastBackupKey) as? Date
    }
    
    func shouldBackupCookies() -> Bool {
        guard let lastBackup = getLastBackupDate() else { return true }
        return Date().timeIntervalSince(lastBackup) > backupInterval
    }
    
    // MARK: - Private Methods
    
    private func saveCookiesToUserDefaults(_ cookies: [HTTPCookie]) {
        let cookieData = cookies.compactMap { cookie -> [String: Any]? in
            var properties: [String: Any] = [
                "name": cookie.name,
                "value": cookie.value,
                "domain": cookie.domain,
                "path": cookie.path
            ]
            
            if let expiresDate = cookie.expiresDate {
                properties["expiresDate"] = expiresDate.timeIntervalSince1970
            }
            
            if cookie.isSecure {
                properties["isSecure"] = true
            }
            
            // Note: HTTPOnly is a server-side flag and cannot be accessed or set by client-side code
            // We'll skip this property as it's not available via HTTPCookie properties
            
            if let comment = cookie.comment {
                properties["comment"] = comment
            }
            
            if let commentURL = cookie.commentURL {
                properties["commentURL"] = commentURL.absoluteString
            }
            
            if let portList = cookie.portList {
                properties["portList"] = portList
            }
            
            // Note: version is not a standard property on HTTPCookie, so we'll skip it
            
            return properties
        }
        
        // Save with error handling and retry
        saveToUserDefaultsWithRetry(cookieData: cookieData)
        
        delegate?.cookieManager(self, didSaveCookies: cookieData.count)
        print("🍪 Backed up \(cookieData.count) cookies to UserDefaults")
    }
    
    private func saveToUserDefaultsWithRetry(cookieData: [[String: Any]], retryCount: Int = 0) {
        let maxRetries = 3
        
        do {
            userDefaults.set(cookieData, forKey: cookieBackupKey)
            userDefaults.set(Date(), forKey: lastBackupKey)
            
            // Force synchronize to ensure data is written
            if userDefaults.synchronize() {
                print("🍪 Cookie backup saved successfully")
            } else {
                throw NSError(domain: "CookieManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to synchronize UserDefaults"])
            }
        } catch {
            print("🍪 Error saving cookies: \(error.localizedDescription)")
            
            if retryCount < maxRetries {
                print("🍪 Retrying cookie backup (attempt \(retryCount + 1)/\(maxRetries))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.saveToUserDefaultsWithRetry(cookieData: cookieData, retryCount: retryCount + 1)
                }
            } else {
                print("🍪 Failed to save cookies after \(maxRetries) attempts")
                delegate?.cookieManager(self, didEncounterError: error)
            }
        }
    }
    
    private func createCookie(from cookieInfo: [String: Any]) -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [:]
        
        guard let name = cookieInfo["name"] as? String,
              let value = cookieInfo["value"] as? String,
              let domain = cookieInfo["domain"] as? String,
              let path = cookieInfo["path"] as? String else {
            return nil
        }
        
        properties[.name] = name
        properties[.value] = value
        properties[.domain] = domain
        properties[.path] = path
        
        if let expiresInterval = cookieInfo["expiresDate"] as? TimeInterval {
            properties[.expires] = Date(timeIntervalSince1970: expiresInterval)
        }
        
        if let isSecure = cookieInfo["isSecure"] as? Bool, isSecure {
            properties[.secure] = "TRUE"
        }
        
        // Note: HTTPOnly is a server-side flag and cannot be accessed or set by client-side code
        // We'll skip this property as it's not available via HTTPCookie properties
        
        if let comment = cookieInfo["comment"] as? String {
            properties[.comment] = comment
        }
        
        if let commentURLString = cookieInfo["commentURL"] as? String,
           let commentURL = URL(string: commentURLString) {
            properties[.commentURL] = commentURL
        }
        
        if let portList = cookieInfo["portList"] as? [NSNumber] {
            properties[.port] = portList
        }
        
        return HTTPCookie(properties: properties)
    }
    
    func cleanupExpiredCookies(from webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            let validCookies = cookies.filter { cookie in
                guard let expiresDate = cookie.expiresDate else { return true }
                return expiresDate > Date()
            }
            
            let expiredCookies = cookies.filter { cookie in
                guard let expiresDate = cookie.expiresDate else { return false }
                return expiresDate <= Date()
            }
            
            if !expiredCookies.isEmpty {
                let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
                for cookie in expiredCookies {
                    cookieStore.delete(cookie) {
                        // Cookie deleted successfully
                    }
                }
                print("🍪 Cleaned up \(expiredCookies.count) expired cookies")
            }
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func appWillTerminate() {
        // Emergency backup when app is about to terminate
        print("🍪 App will terminate - performing emergency cookie backup")
        performEmergencyBackup()
    }
    
    @objc private func appDidBecomeActive() {
        // This is called when the app becomes active
        print("🍪 App became active")
        
        // Check if we need to restore cookies (e.g., after app update)
        checkAndRestoreCookiesIfNeeded()
    }
    
    @objc private func appWillResignActive() {
        // Emergency backup when app goes to background
        print("🍪 App will resign active - performing emergency cookie backup")
        performEmergencyBackup()
    }
    
    private func checkAndRestoreCookiesIfNeeded() {
        // If we have backup cookies but no current cookies, restore them
        let backupCount = getBackupCookieCount()
        if backupCount > 0 {
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    
                    if let webView = self.findWebView(in: rootViewController.view) {
                        print("🍪 App became active - checking if cookies need restoration")
                        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                            if cookies.isEmpty && backupCount > 0 {
                                print("🍪 No current cookies found but backup exists - restoring")
                                self.restoreCookies(to: webView)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Emergency Backup
    
    private func performEmergencyBackup() {
        // Try to get the main WebView and backup cookies immediately
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                // Find the WebView in the view hierarchy
                if let webView = self.findWebView(in: rootViewController.view) {
                    print("🍪 Found WebView - performing emergency backup")
                    self.backupCookies(from: webView)
                } else {
                    print("🍪 WebView not found for emergency backup")
                }
            }
        }
    }
    
    private func findWebView(in view: UIView) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }
        
        for subview in view.subviews {
            if let webView = findWebView(in: subview) {
                return webView
            }
        }
        
        return nil
    }
}

// MARK: - WKWebView Extension

extension WKWebView {
    func backupCookies() {
        CookieManager.shared.backupCookies(from: self)
    }
    
    func restoreCookies() {
        CookieManager.shared.restoreCookies(to: self)
    }
    
    func cleanupExpiredCookies() {
        CookieManager.shared.cleanupExpiredCookies(from: self)
    }
} 