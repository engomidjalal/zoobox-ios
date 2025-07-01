//
//  AppDelegate.swift
//  Zoobox
//
//  Created by omid on 27/06/2025.
//
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        // ❌ DO NOT REQUEST NOTIFICATION PERMISSION HERE ANYMORE!
        // UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        //     print("Notification permission granted: \(granted)")
        // }

        // Register for remote notifications
        application.registerForRemoteNotifications()
        // Set FCM messaging delegate
        Messaging.messaging().delegate = self
        
        // Initialize FCM token cookie manager
        setupFCMTokenCookieManager()
        
        // Initialize connectivity monitoring
        setupConnectivityMonitoring()
        
        // Background tasks removed - using FCM only
        
        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Clean up any resources related to discarded scenes
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Backup cookies before app termination
        print("🍪 App will terminate - backing up cookies")
        // The CookieManager will handle this automatically via notification observers
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Backup cookies when app goes to background
        print("🍪 App entered background - backing up cookies")
        // The CookieManager will handle this automatically via notification observers
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Ensure FCM token is saved as cookie when app becomes active
        print("🔥 App became active - ensuring FCM token is saved as cookie")
        FCMTokenCookieManager.shared.forceSaveCurrentFCMTokenAsCookie()
    }

    // MARK: - Remote Notification Registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass device token to FCM
        Messaging.messaging().apnsToken = deviceToken
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    // MARK: - Background URL Session Handling
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        // Handle background URL session completion for order tracking
        print("🔄 Background URL session completed: \(identifier)")
        completionHandler()
    }

    private func setupConnectivityMonitoring() {
        // Initialize the connectivity manager to start monitoring
        let connectivityManager = ConnectivityManager.shared
        print("📡 AppDelegate: Connectivity monitoring initialized")
    }
    
    private func setupFCMTokenCookieManager() {
        // Initialize FCM token cookie manager
        let fcmTokenManager = FCMTokenCookieManager.shared
        print("🔥 AppDelegate: FCM token cookie manager initialized")
        
        // Try to get existing FCM token and save it as cookie if available
        Messaging.messaging().token { token, error in
            if let error = error {
                print("🔥 Error getting FCM token: \(error)")
                return
            }
            
            if let token = token {
                print("🔥 Got existing FCM token: \(token)")
                Task { @MainActor in
                    fcmTokenManager.saveFCMTokenAsCookie(token)
                }
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        print("🔔 Notification tapped: \(response.notification.request.identifier)")
        
        // Extract notification data
        let userInfo = response.notification.request.content.userInfo
        print("🔔 Notification userInfo: \(userInfo)")
        
        // Handle FCM notification deep linking
        handleFCMNotificationDeepLink(userInfo: userInfo)
        
        completionHandler()
    }
    
    // MARK: - FCM Notification Deep Link Handling
    private func handleFCMNotificationDeepLink(userInfo: [AnyHashable: Any]) {
        print("🔗 Processing FCM notification for deep linking")
        
        // Extract order_type and order_id from notification data
        guard let orderType = userInfo["order_type"] as? String,
              let orderId = userInfo["order_id"] as? String else {
            print("🔗 Missing order_type or order_id in notification data")
            return
        }
        
        print("🔗 Order Type: \(orderType), Order ID: \(orderId)")
        
        // Construct deep link URL based on order type
        var deepLinkURL: URL?
        
        switch orderType.lowercased() {
        case "food":
            // Food order tracking URL
            let urlString = "https://mikmik.site/track_order.php?order_id=\(orderId)"
            deepLinkURL = URL(string: urlString)
            print("🔗 Food order deep link: \(urlString)")
            
        case "d2d":
            // D2D order tracking URL
            let urlString = "https://mikmik.site/d2d/track_d2d.php?order_id=\(orderId)"
            deepLinkURL = URL(string: urlString)
            print("🔗 D2D order deep link: \(urlString)")
            
        default:
            print("🔗 Unknown order type: \(orderType)")
            return
        }
        
        // Open the deep link URL
        if let url = deepLinkURL {
            openDeepLinkURL(url: url)
        }
    }
    
    private func openDeepLinkURL(url: URL) {
        print("🔗 Opening deep link URL: \(url)")
        
        // Post notification to open URL in main view controller
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenDeepLinkURL"),
                object: nil,
                userInfo: ["url": url]
            )
        }
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    // Receive FCM registration token
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 FCM Token received: \(fcmToken ?? "nil")")
        
        // Save FCM token as cookie
        if let token = fcmToken {
            FCMTokenCookieManager.shared.saveFCMTokenAsCookie(token)
        }
    }
}



