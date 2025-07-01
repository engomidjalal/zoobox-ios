//
//  OrderTrackingCookieManager.swift
//  Zoobox
//
//  Created by omid on 27/06/2025.
//

import Foundation
import WebKit

@MainActor
class OrderTrackingCookieManager: NSObject, ObservableObject {
    static let shared = OrderTrackingCookieManager()
    
    @Published var userId: String?
    @Published var isCookieAvailable = false
    
    // Notification names for user_id changes
    static let userDidLoginNotification = Notification.Name("OrderTrackingUserDidLogin")
    static let userDidLogoutNotification = Notification.Name("OrderTrackingUserDidLogout")
    
    private let websiteDataStore = WKWebsiteDataStore.default()
    private let cookieKey = "user_id"
    private let domain = "mikmik.site"
    private let userDefaultsKey = "OrderTracking_UserId"
    
    private var previousUserId: String?
    
    private override init() {
        super.init()
        loadUserIdFromUserDefaults()
        setupCookieMonitoring()
    }
    
    // MARK: - User ID Management
    func getUserId() async -> String? {
        // First try to get from cookies
        if let cookieUserId = await extractUserIdFromCookies() {
            userId = cookieUserId
            isCookieAvailable = true
            saveUserIdToUserDefaults(cookieUserId)
            return cookieUserId
        }
        
        // Fallback to UserDefaults
        if let savedUserId = loadUserIdFromUserDefaults() {
            userId = savedUserId
            isCookieAvailable = false
            return savedUserId
        }
        
        return nil
    }
    
    // MARK: - Cookie Extraction
    private func extractUserIdFromCookies() async -> String? {
        do {
            let cookies = try await websiteDataStore.httpCookieStore.allCookies()
            
            // Look for user_id cookie for mikmik.site
            let targetCookie = cookies.first { cookie in
                cookie.domain.contains(domain) && cookie.name == cookieKey
            }
            
            if let targetCookie = targetCookie {
                print("🍪 Found user_id cookie: \(targetCookie.value)")
                return targetCookie.value
            } else {
                print("🍪 No user_id cookie found for \(domain)")
                return nil
            }
            
        } catch {
            print("🍪 Error accessing cookies: \(error)")
            return nil
        }
    }
    
    // MARK: - Cookie Monitoring
    private func setupCookieMonitoring() {
        // Monitor cookie changes
        websiteDataStore.httpCookieStore.add(self)
    }
    
    @objc private func cookiesDidChange() {
        Task {
            if let newUserId = await extractUserIdFromCookies() {
                await MainActor.run {
                    self.userId = newUserId
                    self.isCookieAvailable = true
                    self.saveUserIdToUserDefaults(newUserId)
                    
                    // Check if this is a new login
                    if self.previousUserId == nil || self.previousUserId != newUserId {
                        print("🍪 User logged in: \(newUserId)")
                        NotificationCenter.default.post(
                            name: OrderTrackingCookieManager.userDidLoginNotification,
                            object: self,
                            userInfo: ["userId": newUserId]
                        )
                    }
                    self.previousUserId = newUserId
                }
                print("🍪 Cookie changed - new user_id: \(newUserId)")
            } else {
                await MainActor.run {
                    // Check if user logged out
                    if self.previousUserId != nil {
                        print("🍪 User logged out: \(self.previousUserId ?? "unknown")")
                        NotificationCenter.default.post(
                            name: OrderTrackingCookieManager.userDidLogoutNotification,
                            object: self,
                            userInfo: ["userId": self.previousUserId ?? ""]
                        )
                    }
                    self.userId = nil
                    self.isCookieAvailable = false
                    self.previousUserId = nil
                }
                print("🍪 Cookie changed - user_id lost")
            }
        }
    }
    
    // MARK: - UserDefaults Fallback
    private func saveUserIdToUserDefaults(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: userDefaultsKey)
        print("🍪 Saved user_id to UserDefaults: \(userId)")
    }
    
    private func loadUserIdFromUserDefaults() -> String? {
        let savedUserId = UserDefaults.standard.string(forKey: userDefaultsKey)
        if let savedUserId = savedUserId {
            print("🍪 Loaded user_id from UserDefaults: \(savedUserId)")
        }
        return savedUserId
    }
    
    // MARK: - Cookie Validation
    func validateCookies() async -> Bool {
        guard let userId = await getUserId() else {
            print("🍪 No valid user_id found")
            return false
        }
        
        // Basic validation - user_id should not be empty
        guard !userId.isEmpty else {
            print("🍪 User_id is empty")
            return false
        }
        
        print("🍪 Cookie validation successful - user_id: \(userId)")
        return true
    }
    
    // MARK: - Manual Cookie Refresh
    func refreshCookies() async {
        print("🍪 Refreshing cookies...")
        
        if let newUserId = await extractUserIdFromCookies() {
            await MainActor.run {
                self.userId = newUserId
                self.isCookieAvailable = true
                self.saveUserIdToUserDefaults(newUserId)
            }
            print("🍪 Cookies refreshed - new user_id: \(newUserId)")
        } else {
            await MainActor.run {
                self.isCookieAvailable = false
            }
            print("🍪 No cookies found during refresh")
        }
    }
    
    // MARK: - Cookie Cleanup
    func clearStoredUserId() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        userId = nil
        isCookieAvailable = false
        print("🍪 Cleared stored user_id")
    }
    
    // MARK: - Debug Information
    func getDebugInfo() async -> [String: Any] {
        let cookieUserId = await extractUserIdFromCookies()
        let savedUserId = loadUserIdFromUserDefaults()
        
        return [
            "cookie_user_id": cookieUserId ?? "nil",
            "saved_user_id": savedUserId ?? "nil",
            "current_user_id": userId ?? "nil",
            "is_cookie_available": isCookieAvailable,
            "domain": domain,
            "cookie_key": cookieKey
        ]
    }
    
    deinit {
        websiteDataStore.httpCookieStore.remove(self)
    }
}

// MARK: - WKHTTPCookieStoreObserver
extension OrderTrackingCookieManager: WKHTTPCookieStoreObserver {
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        cookiesDidChange()
    }
} 