//
//  OrderTrackingModels.swift
//  Zoobox
//
//  Created by omid on 27/06/2025.
//

import Foundation
import UserNotifications

// MARK: - API Response Models
struct OrderResponse: Codable {
    let success: Bool
    let count: Int
    let notifications: [OrderNotification]
}

struct OrderNotification: Codable, Identifiable {
    let orderId: String
    let type: OrderStatusType
    let message: String
    let hero: String?
    let timestamp: String
    let date: String
    
    var id: String { orderId }
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case type
        case message
        case hero
        case timestamp
        case date
    }
}

enum OrderStatusType: String, Codable, CaseIterable {
    case heroAssigned = "hero_assigned"
    case arrival = "arrival"
    case pickup = "pickup"
    case delivered = "delivered"
    
    var displayName: String {
        switch self {
        case .heroAssigned:
            return "Hero Assigned"
        case .arrival:
            return "Hero Arrived"
        case .pickup:
            return "Order Picked Up"
        case .delivered:
            return "Order Delivered"
        }
    }
    
    var emoji: String {
        switch self {
        case .heroAssigned:
            return "👨‍🍳"
        case .arrival:
            return "🚗"
        case .pickup:
            return "📦"
        case .delivered:
            return "✅"
        }
    }
    
    var notificationTitle: String {
        switch self {
        case .heroAssigned:
            return "👨‍🍳 Hero Assigned!"
        case .arrival:
            return "🚗 Hero Arrived!"
        case .pickup:
            return "📦 Order Picked Up!"
        case .delivered:
            return "✅ Order Delivered!"
        }
    }
    
    var notificationSound: String {
        switch self {
        case .heroAssigned:
            return "hero_assigned.wav"
        case .arrival:
            return "arrival.wav"
        case .pickup:
            return "pickup.wav"
        case .delivered:
            return "delivered.wav"
        }
    }
}

// MARK: - Tracking State Models
struct TrackingState: Codable {
    let isActive: Bool
    let lastUpdateTime: Date?
    let lastNotificationId: String?
    let userId: String?
    
    static let empty = TrackingState(
        isActive: false,
        lastUpdateTime: nil,
        lastNotificationId: nil,
        userId: nil
    )
}

// MARK: - Background Task Configuration
struct BackgroundTaskConfig {
    static let refreshTaskIdentifier = "com.zoobox.orderTrackingRefresh"
    static let processingTaskIdentifier = "com.zoobox.orderTrackingProcessing"
    
    static let refreshInterval: TimeInterval = 15 // 15 seconds
    static let processingInterval: TimeInterval = 300 // 5 minutes
    static let fallbackInterval: TimeInterval = 600 // 10 minutes
    
    static let apiEndpoint = "https://mikmik.site/notification_checker.php"
    static let trackingEndpoint = "https://mikmik.site/track_order.php"
}

// MARK: - Notification Categories
enum NotificationCategory: String, CaseIterable {
    case orderUpdate = "ORDER_UPDATE"
    case orderStatus = "ORDER_STATUS"
    
    var identifier: String {
        return rawValue
    }
    
    var actions: [UNNotificationAction] {
        switch self {
        case .orderUpdate:
            return [
                UNNotificationAction(
                    identifier: "VIEW_ORDER",
                    title: "View Order",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "DISMISS",
                    title: "Dismiss",
                    options: [.destructive]
                )
            ]
        case .orderStatus:
            return [
                UNNotificationAction(
                    identifier: "TRACK_ORDER",
                    title: "Track Order",
                    options: [.foreground]
                )
            ]
        }
    }
} 