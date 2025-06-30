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
        
        // Initialize connectivity monitoring
        setupConnectivityMonitoring()
        
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

    // MARK: - Remote Notification Registration
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Pass device token to FCM
        Messaging.messaging().apnsToken = deviceToken
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }

    private func setupConnectivityMonitoring() {
        // Initialize the connectivity manager to start monitoring
        let connectivityManager = ConnectivityManager.shared
        print("📡 AppDelegate: Connectivity monitoring initialized")
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
        completionHandler()
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    // Receive FCM registration token
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM Token: \(fcmToken ?? "")")
        // Optionally, send this token to your server if you want to target this device
    }
}



