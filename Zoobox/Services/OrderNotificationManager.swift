//
//  OrderNotificationManager.swift
//  Zoobox
//
//  Created by omid on 27/06/2025.
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class OrderNotificationManager: ObservableObject {
    static let shared = OrderNotificationManager()
    
    @Published var isAuthorized = false
    @Published var lastNotificationTime: Date?
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    private init() {
        setupNotificationCategories()
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestPermissions() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional]
            let granted = try await notificationCenter.requestAuthorization(options: options)
            
            await MainActor.run {
                self.isAuthorized = granted
            }
            
            if granted {
                print("🔔 Notification permissions granted")
            } else {
                print("🔔 Notification permissions denied")
            }
            
            return granted
        } catch {
            print("🔔 Error requesting notification permissions: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Notification Categories Setup
    private func setupNotificationCategories() {
        var categories: Set<UNNotificationCategory> = []
        
        for category in NotificationCategory.allCases {
            let notificationCategory = UNNotificationCategory(
                identifier: category.identifier,
                actions: category.actions,
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
            categories.insert(notificationCategory)
        }
        
        notificationCenter.setNotificationCategories(categories)
    }
    
    // MARK: - Notification Scheduling
    func scheduleNotification(for order: OrderNotification) {
        guard isAuthorized else {
            print("🔔 Notifications not authorized")
            return
        }
        
        // Check if we've already shown this notification
        let notificationId = "\(order.orderId)_\(order.type.rawValue)"
        if hasShownNotification(id: notificationId) {
            print("🔔 Notification already shown for: \(notificationId)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = order.type.notificationTitle
        content.body = order.message
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = NotificationCategory.orderStatus.identifier
        content.userInfo = [
            "order_id": order.orderId,
            "order_type": order.type.rawValue,
            "order_date": order.date,
            "hero": order.hero ?? ""
        ]
        
        // Add custom sound if available
        if let customSound = getCustomNotificationSound(for: order.type) {
            content.sound = customSound
        }
        
        // Create trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        notificationCenter.add(request) { [weak self] error in
            if let error = error {
                print("🔔 Error scheduling notification: \(error)")
            } else {
                print("🔔 Notification scheduled for order: \(order.orderId)")
                self?.markNotificationAsShown(id: notificationId)
                self?.lastNotificationTime = Date()
                
                // Trigger haptic feedback
                DispatchQueue.main.async {
                    self?.hapticFeedback.impactOccurred()
                }
            }
        }
    }
    
    // MARK: - Notification Tracking
    private func hasShownNotification(id: String) -> Bool {
        return UserDefaults.standard.bool(forKey: "shown_notification_\(id)")
    }
    
    private func markNotificationAsShown(id: String) {
        UserDefaults.standard.set(true, forKey: "shown_notification_\(id)")
    }
    
    func clearNotificationHistory() {
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        let notificationKeys = keys.filter { $0.hasPrefix("shown_notification_") }
        
        for key in notificationKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        print("🔔 Cleared notification history")
    }
    
    // MARK: - Custom Sounds
    private func getCustomNotificationSound(for type: OrderStatusType) -> UNNotificationSound? {
        // In a real app, you would bundle these sound files
        // For now, we'll use system sounds
        switch type {
        case .heroAssigned:
            return UNNotificationSound.default
        case .arrival:
            return UNNotificationSound.default
        case .pickup:
            return UNNotificationSound.default
        case .delivered:
            return UNNotificationSound.default
        }
    }
    
    // MARK: - Notification Actions
    func handleNotificationAction(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "VIEW_ORDER":
            handleViewOrder(userInfo: userInfo)
        case "TRACK_ORDER":
            handleTrackOrder(userInfo: userInfo)
        case "DISMISS":
            // Just dismiss, no action needed
            break
        default:
            // Default action - open the app
            break
        }
    }
    
    private func handleViewOrder(userInfo: [AnyHashable: Any]) {
        guard let orderId = userInfo["order_id"] as? String,
              let date = userInfo["order_date"] as? String else {
            return
        }
        
        // Open the tracking URL
        if let url = OrderTrackingAPIClient.shared.getTrackingURL(orderId: orderId, date: date) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func handleTrackOrder(userInfo: [AnyHashable: Any]) {
        handleViewOrder(userInfo: userInfo)
    }
    
    // MARK: - Batch Notifications
    func scheduleBatchNotifications(for orders: [OrderNotification]) {
        for order in orders {
            scheduleNotification(for: order)
        }
    }
    
    // MARK: - Notification Management
    func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("🔔 Removed all pending notifications")
    }
    
    func removeAllDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        print("🔔 Removed all delivered notifications")
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }
    
    func getDeliveredNotifications() async -> [UNNotification] {
        return await notificationCenter.deliveredNotifications()
    }
} 