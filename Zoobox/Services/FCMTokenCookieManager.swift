//
//  FCMTokenCookieManager.swift
//  Zoobox
//
//  Created by omid on 27/06/2025.
//

import Foundation
import WebKit
import FirebaseMessaging
import Network

@MainActor
class FCMTokenCookieManager: NSObject, ObservableObject {
    static let shared = FCMTokenCookieManager()
    
    @Published var currentFCMToken: String?
    @Published var isTokenSaved = false
    
    // MARK: - Properties for Apple Guideline Compliance
    @Published var lastTokenSaveStatus: String = "Not started"
    @Published var lastTokenSaveTime: Date?
    
    private let websiteDataStore = WKWebsiteDataStore.default()
    private let cookieName = "FCM_token"
    private let domain = "mikmik.site"
    private let userDefaultsKey = "FCM_Token_Backup"
    private var previousUserId: String?
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    private var isNetworkAvailable = false
    
    private override init() {
        super.init()
        loadTokenFromUserDefaults()
        setupTokenMonitoring()
        setupNetworkMonitoring()
        
        // Initialize previousUserId and check if both cookies exist on app startup
        // Use Task.detached to avoid potential deadlock in init
        Task.detached { [weak self] in
            await self?.initializeUserIdTracking()
            await self?.postFCMTokenAndUserIdIfNeeded()
        }
    }
    
    // MARK: - FCM Token Management
    
    /// Save FCM token as a cookie
    /// - Parameter token: The FCM token to save
    func saveFCMTokenAsCookie() {
        // FIXED: Apple Guideline 4.5.4 - Push notifications must be optional
        // App must function normally even without FCM tokens
        
        // Add retry logic for FCM token requests
        attemptFCMTokenRequest(retryCount: 3)
    }
    
    private func attemptFCMTokenRequest(retryCount: Int) {
        guard retryCount > 0 else {
            print("🔥 [FCMTokenCookieManager] ❌ Max retries reached - FCM token request failed")
            self.lastTokenSaveStatus = "Max retries reached (optional)"
            return
        }
        
        // Check network availability before making request
        guard isNetworkAvailable else {
            print("🔥 [FCMTokenCookieManager] 🌐 Network unavailable - retrying FCM token request...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.attemptFCMTokenRequest(retryCount: retryCount - 1)
            }
            return
        }
        
        Messaging.messaging().token { [weak self] token, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    print("🔥 [FCMTokenCookieManager] ℹ️ FCM token error (retry \(4 - retryCount)/3): \(error.localizedDescription)")
                    
                    // Retry after a delay for certain errors
                    if self.shouldRetryForError(error) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.attemptFCMTokenRequest(retryCount: retryCount - 1)
                        }
                    } else {
                        self.lastTokenSaveStatus = "FCM token error (optional)"
                    }
                    return
                }
                
                guard let token = token, !token.isEmpty else {
                    print("🔥 [FCMTokenCookieManager] ℹ️ No FCM token available - retrying...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.attemptFCMTokenRequest(retryCount: retryCount - 1)
                    }
                    return
                }
                
                // Validate token format
                if self.isValidFCMToken(token) {
                    self.saveFCMTokenAsCookie(token: token)
                } else {
                    print("🔥 [FCMTokenCookieManager] ❌ Invalid FCM token format - retrying...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.attemptFCMTokenRequest(retryCount: retryCount - 1)
                    }
                }
            }
        }
    }
    
    private func shouldRetryForError(_ error: Error) -> Bool {
        let errorCode = (error as NSError).code
        // Retry for network errors, but not for auth errors
        return errorCode != -1012 && errorCode != -1009 // Not auth error or offline
    }
    
    private func isValidFCMToken(_ token: String) -> Bool {
        // Basic FCM token validation - should be at least 30 characters and contain colons
        return token.count > 30 && token.contains(":")
    }
    
    private func saveFCMTokenAsCookie(token: String) {
        print("🔥 [FCMTokenCookieManager] 💾 Saving FCM token as cookie (optional feature)")
        print("🔥 [FCMTokenCookieManager] Token: \(token.prefix(20))...")
        
        // Create cookie with FCM token
        let cookie = HTTPCookie(properties: [
            .domain: "mikmik.site",
            .path: "/",
            .name: cookieName,
            .value: token,
            .secure: "TRUE",
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 30) // 30 days
        ])
        
        guard let cookie = cookie else {
            print("🔥 [FCMTokenCookieManager] ℹ️ Failed to create FCM cookie (app continues normally)")
            self.lastTokenSaveStatus = "Cookie creation failed (optional)"
            return
        }
        
        // Save cookie to WebView data store
        websiteDataStore.httpCookieStore.setCookie(cookie) { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                print("🔥 [FCMTokenCookieManager] ✅ FCM token saved as cookie successfully")
                self.lastTokenSaveStatus = "FCM token saved successfully"
                self.lastTokenSaveTime = Date()
                
                // Save to UserDefaults as backup
                self.saveTokenToUserDefaults(token)
                
                // Optional: Post token to server if user_id is available
                Task {
                    await self.postTokenToServerIfUserIdExists(token: token)
                }
            }
        }
    }
    
    /// Get current FCM token from cookie
    /// - Returns: The FCM token if available
    func getFCMTokenFromCookie() async -> String? {
        do {
            let cookies = try await websiteDataStore.httpCookieStore.allCookies()
            
            // Look for FCM_token cookie
            let fcmCookie = cookies.first { cookie in
                cookie.domain.contains(domain) && cookie.name == cookieName
            }
            
            if let fcmCookie = fcmCookie {
                await MainActor.run {
                    self.currentFCMToken = fcmCookie.value
                    self.isTokenSaved = true
                }
                print("🔥 Found FCM token in cookie: \(fcmCookie.value)")
                return fcmCookie.value
            } else {
                print("🔥 No FCM token cookie found")
                return nil
            }
            
        } catch {
            print("🔥 Error accessing FCM token cookie: \(error)")
            return nil
        }
    }
    
    /// Update FCM token if it has changed
    /// - Parameter newToken: The new FCM token
    func updateFCMTokenIfNeeded(_ newToken: String?) {
        guard let newToken = newToken, !newToken.isEmpty else {
            print("🔥 New FCM token is empty or nil")
            return
        }
        
        // Check if token has changed
        if currentFCMToken != newToken {
            print("🔥 🔥 🔥 FCM TOKEN CHANGED - SAVING NEW TOKEN AS COOKIE")
            print("🔥 Previous token: \(currentFCMToken ?? "nil")")
            print("🔥 New token: \(newToken)")
            saveFCMTokenAsCookie(token: newToken)
        } else {
            print("🔥 FCM token unchanged: \(newToken)")
        }
    }
    
    /// Refresh FCM token from Firebase
    func refreshFCMToken() {
        print("🔥 🔥 🔥 REFRESHING FCM TOKEN FROM FIREBASE")
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("🔥 Error refreshing FCM token: \(error)")
                return
            }
            
            if let token = token {
                print("🔥 🔥 🔥 FCM TOKEN REFRESHED - SAVING AS COOKIE: \(token)")
                Task { @MainActor in
                    self?.updateFCMTokenIfNeeded(token)
                }
            } else {
                print("🔥 No FCM token received from refresh")
            }
        }
    }
    
    /// Force save current FCM token as cookie (gets fresh token from Firebase)
    func forceSaveCurrentFCMTokenAsCookie() {
        print("🔥 🔥 🔥 FORCE SAVING CURRENT FCM TOKEN AS COOKIE")
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                print("🔥 Error getting current FCM token: \(error)")
                return
            }
            
            if let token = token {
                print("🔥 🔥 🔥 FORCE SAVING FCM TOKEN AS COOKIE: \(token)")
                Task { @MainActor in
                    self?.saveFCMTokenAsCookie(token: token)
                }
            } else {
                print("🔥 No current FCM token available for force save")
            }
        }
    }
    
    // MARK: - UserDefaults Backup
    
    private func saveTokenToUserDefaults(_ token: String) {
        UserDefaults.standard.set(token, forKey: userDefaultsKey)
        print("🔥 Saved FCM token to UserDefaults: \(token)")
    }
    
    private func loadTokenFromUserDefaults() {
        if let savedToken = UserDefaults.standard.string(forKey: userDefaultsKey) {
            currentFCMToken = savedToken
            print("🔥 Loaded FCM token from UserDefaults: \(savedToken)")
        }
    }
    
    // MARK: - Token Monitoring
    
    private func setupTokenMonitoring() {
        // Monitor cookie changes
        websiteDataStore.httpCookieStore.add(self)
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isAvailable = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isNetworkAvailable = isAvailable
                print("🔥 [FCMTokenCookieManager] 🌐 Network status: \(isAvailable ? "Available" : "Unavailable")")
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - Cookie Validation
    
    /// Validate FCM token cookie
    /// - Returns: True if valid FCM token cookie exists
    func validateFCMTokenCookie() async -> Bool {
        guard let token = await getFCMTokenFromCookie() else {
            print("🔥 No valid FCM token cookie found")
            return false
        }
        
        // Basic validation - token should not be empty
        guard !token.isEmpty else {
            print("🔥 FCM token is empty")
            return false
        }
        
        print("🔥 FCM token cookie validation successful")
        return true
    }
    
    // MARK: - Cleanup
    
    /// Clear FCM token cookie
    func clearFCMTokenCookie() async {
        do {
            let cookies = try await websiteDataStore.httpCookieStore.allCookies()
            
            // Find and delete FCM token cookie
            let fcmCookie = cookies.first { cookie in
                cookie.domain.contains(domain) && cookie.name == cookieName
            }
            
            if let fcmCookie = fcmCookie {
                try await websiteDataStore.httpCookieStore.delete(fcmCookie)
                
                await MainActor.run {
                    self.currentFCMToken = nil
                    self.isTokenSaved = false
                }
                
                // Clear from UserDefaults
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                
                print("🔥 FCM token cookie cleared")
            }
            
        } catch {
            print("🔥 Error clearing FCM token cookie: \(error)")
        }
    }
    
    /// Clear stored FCM token
    func clearStoredToken() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        currentFCMToken = nil
        isTokenSaved = false
        print("🔥 Cleared stored FCM token")
    }
    
    // MARK: - Debug Information
    
    func getDebugInfo() async -> [String: Any] {
        let cookieToken = await getFCMTokenFromCookie()
        let savedToken = UserDefaults.standard.string(forKey: userDefaultsKey)
        let userId = await extractUserIdFromCookies()
        
        return [
            "cookie_fcm_token": cookieToken ?? "nil",
            "saved_fcm_token": savedToken ?? "nil",
            "current_fcm_token": currentFCMToken ?? "nil",
            "is_token_saved": isTokenSaved,
            "current_user_id": userId ?? "nil",
            "previous_user_id": previousUserId ?? "nil",
            "domain": domain,
            "cookie_name": cookieName
        ]
    }
    
    /// Comprehensive verification of FCM token cookie status
    func verifyFCMTokenCookieStatus() async {
        print("🔥 🔥 🔥 VERIFYING FCM TOKEN COOKIE STATUS 🔥 🔥 🔥")
        
        // Get current FCM token from Firebase
        Messaging.messaging().token { [weak self] firebaseToken, error in
            if let error = error {
                print("🔥 ❌ Error getting Firebase FCM token: \(error)")
                return
            }
            
            Task {
                let cookieToken = await self?.getFCMTokenFromCookie()
                let savedToken = UserDefaults.standard.string(forKey: self?.userDefaultsKey ?? "")
                
                print("🔥 Firebase FCM Token: \(firebaseToken ?? "nil")")
                print("🔥 Cookie FCM Token: \(cookieToken ?? "nil")")
                print("🔥 Saved FCM Token: \(savedToken ?? "nil")")
                print("🔥 Current FCM Token: \(self?.currentFCMToken ?? "nil")")
                print("🔥 Is Token Saved: \(self?.isTokenSaved ?? false)")
                
                // Check if we need to save the token
                if let firebaseToken = firebaseToken, !firebaseToken.isEmpty {
                    if cookieToken != firebaseToken {
                        print("🔥 🔥 🔥 MISMATCH DETECTED - SAVING FCM TOKEN AS COOKIE 🔥 🔥 🔥")
                        await self?.saveFCMTokenAsCookie(token: firebaseToken)
                    } else {
                        print("🔥 ✅ FCM Token cookie is up to date")
                    }
                } else {
                    print("🔥 ❌ No Firebase FCM token available")
                }
                
                print("🔥 🔥 🔥 FCM TOKEN COOKIE VERIFICATION COMPLETE 🔥 🔥 🔥")
            }
        }
    }
    
    /// Post FCM_token and user_id to the provided URL if both cookies exist
    private func postFCMTokenAndUserIdIfNeeded() async {
        // Get FCM_token from cookie
        let fcmToken = await self.getFCMTokenFromCookie()
        // Get user_id from cookies directly
        let userId = await extractUserIdFromCookies()
        
        guard let fcmToken = fcmToken, !fcmToken.isEmpty,
              let userId = userId, !userId.isEmpty else {
            print("🔥 [FCMTokenCookieManager] Skipping POST: FCM_token or user_id missing.")
            print("🔥 FCM_token: \(fcmToken?.prefix(10) ?? "nil")")
            print("🔥 user_id: \(userId?.prefix(10) ?? "nil")")
            return
        }
        
        print("🔥 [FCMTokenCookieManager] POSTING to FCM token updater API")
        print("🔥 FCM_token: \(fcmToken.prefix(10))...")
        print("🔥 user_id: \(userId.prefix(10))...")
        print("🔥 device_type: ios")
        
        let urlString = "https://mikmik.site/FCM_token_updater.php"
        guard let url = URL(string: urlString) else {
            print("🔥 [FCMTokenCookieManager] Invalid URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let bodyString = "user_id=\(userId)&FCM_token=\(fcmToken)&device_type=ios"
        request.httpBody = bodyString.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("🔥 [FCMTokenCookieManager] POST error: \(error)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("🔥 [FCMTokenCookieManager] POST response status: \(httpResponse.statusCode)")
            }
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("🔥 [FCMTokenCookieManager] POST response body: \(responseString)")
            }
        }
        task.resume()
    }
    
    /// Extract user_id from cookies directly
    private func extractUserIdFromCookies() async -> String? {
        do {
            let cookies = try await websiteDataStore.httpCookieStore.allCookies()
            
            // Look for user_id cookie for mikmik.site
            let targetCookie = cookies.first { cookie in
                cookie.domain.contains("mikmik.site") && cookie.name == "user_id"
            }
            
            if let targetCookie = targetCookie {
                print("🔥 Found user_id cookie: \(targetCookie.value)")
                return targetCookie.value
            } else {
                print("🔥 No user_id cookie found")
                return nil
            }
            
        } catch {
            print("🔥 Error accessing cookies: \(error)")
            return nil
        }
    }
    
    /// Public function to manually trigger posting both cookies to API
    func postBothCookiesToAPI() async {
        await postFCMTokenAndUserIdIfNeeded()
    }
    
    /// Public function to manually check and post both cookies if available
    func checkAndPostBothCookies() async {
        await checkAndPostBothCookiesIfAvailable()
    }
    
    /// Initialize user_id tracking by getting current user_id from cookies
    private func initializeUserIdTracking() async {
        let userId = await extractUserIdFromCookies()
        if let userId = userId, !userId.isEmpty {
            previousUserId = userId
            print("🔥 Initialized user_id tracking with: \(userId.prefix(10))")
        } else {
            print("🔥 No user_id cookie found during initialization")
        }
    }
    
    deinit {
        websiteDataStore.httpCookieStore.remove(self)
        networkMonitor.cancel()
    }
    
    // MARK: - Server Integration (Optional)
    
    /// Optional: Post token to server if user_id is available
    /// This is completely optional and won't block app functionality
    private func postTokenToServerIfUserIdExists(token: String) async {
        print("🔥 [FCMTokenCookieManager] 🌐 Checking if user_id exists to post token to server (optional)")
        
        // Check if user_id cookie exists
        do {
            let cookies = try await websiteDataStore.httpCookieStore.allCookies()
            let userIdCookie = cookies.first { cookie in
                cookie.domain.contains("mikmik.site") && cookie.name == "user_id"
            }
            
            guard let userIdCookie = userIdCookie else {
                print("🔥 [FCMTokenCookieManager] ℹ️ No user_id cookie found - skipping server post (app continues normally)")
                return
            }
            
            print("🔥 [FCMTokenCookieManager] 🌐 Posting FCM token to server (optional)")
            
            // Post token to server
            await postTokenToServer(token: token, userId: userIdCookie.value)
            
        } catch {
            print("🔥 [FCMTokenCookieManager] ℹ️ Error accessing cookies (app continues normally): \(error)")
        }
    }
    
    /// Post FCM token to server
    private func postTokenToServer(token: String, userId: String) async {
        print("🔥 [FCMTokenCookieManager] 🌐 Posting token to server for user: \(userId.prefix(10))...")
        
        // Use the same endpoint as the main POST function
        let url = URL(string: "https://mikmik.site/FCM_token_updater.php")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyString = "user_id=\(userId)&FCM_token=\(token)&device_type=ios"
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔥 [FCMTokenCookieManager] 🌐 Server response: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🔥 [FCMTokenCookieManager] 🌐 Server response body: \(responseString)")
                }
            }
            
        } catch {
            print("🔥 [FCMTokenCookieManager] ℹ️ Server post failed (app continues normally): \(error)")
        }
    }
}

// MARK: - WKHTTPCookieStoreObserver
extension FCMTokenCookieManager: WKHTTPCookieStoreObserver {
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task {
            // Check if FCM token cookie changed
            if let newToken = await getFCMTokenFromCookie() {
                await MainActor.run {
                    if self.currentFCMToken != newToken {
                        print("🔥 FCM token cookie changed: \(newToken)")
                        self.currentFCMToken = newToken
                        self.isTokenSaved = true
                    }
                }
            } else {
                await MainActor.run {
                    if self.currentFCMToken != nil {
                        print("🔥 FCM token cookie removed")
                        self.currentFCMToken = nil
                        self.isTokenSaved = false
                    }
                }
            }
            
            // Check if user_id cookie changed and both cookies are now available
            await checkAndPostBothCookiesIfAvailable()
        }
    }
    
    /// Check if both FCM_token and user_id cookies are available and post to API
    private func checkAndPostBothCookiesIfAvailable() async {
        let fcmToken = await getFCMTokenFromCookie()
        let userId = await extractUserIdFromCookies()
        
        // Check if user_id cookie changed
        if let userId = userId, !userId.isEmpty {
            if previousUserId != userId {
                print("🔥 user_id cookie changed from '\(previousUserId?.prefix(10) ?? "nil")' to '\(userId.prefix(10))'")
                previousUserId = userId
            }
        } else {
            if previousUserId != nil {
                print("🔥 user_id cookie was removed")
                previousUserId = nil
            }
        }
        
        if let fcmToken = fcmToken, !fcmToken.isEmpty,
           let userId = userId, !userId.isEmpty {
            print("🔥 Both FCM_token and user_id cookies available - posting to API")
            await postFCMTokenAndUserIdIfNeeded()
        } else {
            print("🔥 Not all required cookies available - FCM_token: \(fcmToken?.prefix(10) ?? "nil"), user_id: \(userId?.prefix(10) ?? "nil")")
        }
    }
    
    /// Public function to be called on page refresh to check and post both cookies
    func checkAndPostCookiesOnPageRefresh() async {
        print("🔥 Page refresh detected - checking and posting cookies if available")
        await checkAndPostBothCookiesIfAvailable()
    }
} 