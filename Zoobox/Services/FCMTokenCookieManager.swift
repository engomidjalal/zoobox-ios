//
//  FCMTokenCookieManager.swift
//  Zoobox
//
//  Created by omid on 27/06/2025.
//

import Foundation
import WebKit
import FirebaseMessaging

@MainActor
class FCMTokenCookieManager: NSObject, ObservableObject {
    static let shared = FCMTokenCookieManager()
    
    @Published var currentFCMToken: String?
    @Published var isTokenSaved = false
    
    private let websiteDataStore = WKWebsiteDataStore.default()
    private let cookieName = "FCM_token"
    private let domain = "mikmik.site"
    private let userDefaultsKey = "FCM_Token_Backup"
    private var previousUserId: String?
    
    private override init() {
        super.init()
        loadTokenFromUserDefaults()
        setupTokenMonitoring()
        
        // Initialize previousUserId and check if both cookies exist on app startup
        Task {
            await initializeUserIdTracking()
            await postFCMTokenAndUserIdIfNeeded()
        }
    }
    
    // MARK: - FCM Token Management
    
    /// Save FCM token as a cookie
    /// - Parameter token: The FCM token to save
    func saveFCMTokenAsCookie(_ token: String?) {
        guard let token = token, !token.isEmpty else {
            print("🔥 FCM Token is empty or nil - cannot save as cookie")
            return
        }
        
        print("🔥 🔥 🔥 SAVING FCM TOKEN AS COOKIE: \(token)")
        
        Task {
            await createFCMTokenCookie(token: token)
        }
    }
    
    /// Create FCM token cookie in WebView
    /// - Parameter token: The FCM token value
    private func createFCMTokenCookie(token: String) async {
        do {
            // Create cookie properties
            var cookieProperties: [HTTPCookiePropertyKey: Any] = [
                .name: cookieName,
                .value: token,
                .domain: domain,
                .path: "/"
            ]
            
            // Set expiration to 1 year from now
            let expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
            cookieProperties[.expires] = expirationDate
            
            // Create the cookie
            guard let cookie = HTTPCookie(properties: cookieProperties) else {
                print("🔥 Failed to create FCM token cookie")
                return
            }
            
            // Add cookie to WebView store
            try await websiteDataStore.httpCookieStore.setCookie(cookie)
            
            await MainActor.run {
                self.currentFCMToken = token
                self.isTokenSaved = true
            }
            
            // Backup token to UserDefaults
            saveTokenToUserDefaults(token)
            
            print("🔥 FCM Token saved as cookie: \(token)")

            // After saving the FCM token as a cookie, check if both cookies are now available
            await checkAndPostBothCookiesIfAvailable()
            
        } catch {
            print("🔥 Error saving FCM token as cookie: \(error)")
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
            saveFCMTokenAsCookie(newToken)
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
                    self?.saveFCMTokenAsCookie(token)
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
                        await self?.saveFCMTokenAsCookie(firebaseToken)
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