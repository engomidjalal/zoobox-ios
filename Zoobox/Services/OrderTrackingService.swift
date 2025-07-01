//
//  OrderTrackingService.swift
//  Zoobox
//
//  Created by omid on 27/06/2025.
//

import Foundation
import UIKit

@MainActor
class OrderTrackingService: NSObject, ObservableObject {
    static let shared = OrderTrackingService()
    
    // MARK: - Published Properties
    @Published var isTracking = false
    @Published var isConnected = false
    @Published var lastUpdateTime: Date?
    @Published var lastNotificationId: String?
    @Published var errorMessage: String?
    @Published var notificationCount = 0
    
    // MARK: - Private Properties
    private var timer: Timer?
    private var isInForeground = true
    private let trackingStateKey = "OrderTracking_State"
    
    // MARK: - Dependencies
    private let apiClient = OrderTrackingAPIClient.shared
    private let notificationManager = OrderNotificationManager.shared
    private let cookieManager = OrderTrackingCookieManager.shared
    private let backgroundTaskManager = BackgroundTaskManager.shared
    
    private override init() {
        super.init()
        loadTrackingState()
        setupObservers()
    }
    
    // MARK: - Public Interface
    func startTracking() async {
        guard !isTracking else {
            print("📦 Order tracking already active")
            return
        }
        
        // Request notification permissions first
        let permissionsGranted = await notificationManager.requestPermissions()
        if !permissionsGranted {
            errorMessage = "Notification permissions required for order tracking"
            return
        }
        
        // Validate cookies/user ID
        guard await cookieManager.validateCookies() else {
            errorMessage = "User authentication required. Please log in first."
            return
        }
        
        // Start tracking
        isTracking = true
        errorMessage = nil
        
        if isInForeground {
            startForegroundTracking()
        } else {
            startBackgroundTracking()
        }
        
        saveTrackingState()
        print("📦 Order tracking started")
    }
    
    func stopTracking() {
        guard isTracking else {
            print("📦 Order tracking not active")
            return
        }
        
        isTracking = false
        stopForegroundTracking()
        backgroundTaskManager.cancelAllBackgroundTasks()
        
        saveTrackingState()
        print("📦 Order tracking stopped")
    }
    
    func pauseTracking() {
        // Invalidate timer on main thread since it's UI-related
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
        }
        print("📦 Order tracking paused")
    }
    
    func resumeTracking() {
        guard isTracking else { return }
        
        if isInForeground {
            startForegroundTracking()
        } else {
            startBackgroundTracking()
        }
        
        print("📦 Order tracking resumed")
    }
    
    // MARK: - Foreground Tracking
    private func startForegroundTracking() {
        stopForegroundTracking()
        
        // Start timer for foreground polling
        timer = Timer.scheduledTimer(withTimeInterval: BackgroundTaskConfig.refreshInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performOrderCheck()
            }
        }
        
        // Perform initial check
        Task {
            await performOrderCheck()
        }
    }
    
    private func stopForegroundTracking() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Background Tracking
    private func startBackgroundTracking() {
        backgroundTaskManager.scheduleBackgroundTasks()
    }
    
    // MARK: - Order Checking
    private func performOrderCheck() async {
        guard isTracking else { return }
        
        do {
            guard let userId = await cookieManager.getUserId() else {
                throw OrderTrackingError.noUserId
            }
            
            let response = try await apiClient.checkOrdersWithRetry(userId: userId)
            
            if response.success && response.count > 0 {
                print("📦 Found \(response.count) new notifications")
                notificationCount += response.count
                
                // Schedule notifications
                await notificationManager.scheduleBatchNotifications(for: response.notifications)
                
                // Update state
                lastUpdateTime = Date()
                lastNotificationId = response.notifications.last?.id
                
                saveTrackingState()
                
            } else {
                print("📦 No new notifications found")
            }
            
        } catch {
            print("📦 Order check failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - State Management
    func updateTrackingState(lastUpdateTime: Date?, lastNotificationId: String?) {
        self.lastUpdateTime = lastUpdateTime
        self.lastNotificationId = lastNotificationId
        saveTrackingState()
    }
    
    private func saveTrackingState() {
        let state = TrackingState(
            isActive: isTracking,
            lastUpdateTime: lastUpdateTime,
            lastNotificationId: lastNotificationId,
            userId: cookieManager.userId
        )
        
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: trackingStateKey)
        }
    }
    
    private func loadTrackingState() {
        guard let data = UserDefaults.standard.data(forKey: trackingStateKey),
              let state = try? JSONDecoder().decode(TrackingState.self, from: data) else {
            return
        }
        
        lastUpdateTime = state.lastUpdateTime
        lastNotificationId = state.lastNotificationId
        
        // Don't auto-start tracking, let user decide
        print("📦 Loaded tracking state: active=\(state.isActive)")
    }
    
    // MARK: - App State Observers
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        isInForeground = false
        pauseTracking()
        backgroundTaskManager.handleAppDidEnterBackground()
    }
    
    @objc private func appWillEnterForeground() {
        isInForeground = true
        backgroundTaskManager.handleAppWillEnterForeground()
        
        if isTracking {
            resumeTracking()
        }
    }
    
    @objc private func appWillTerminate() {
        backgroundTaskManager.handleAppWillTerminate()
    }
    
    // MARK: - Debug Information
    func getDebugInfo() async -> [String: Any] {
        let cookieInfo = await cookieManager.getDebugInfo()
        let pendingTasks = await backgroundTaskManager.getPendingTasks()
        
        return [
            "is_tracking": isTracking,
            "is_connected": apiClient.isConnected,
            "is_in_foreground": isInForeground,
            "last_update_time": lastUpdateTime?.description ?? "nil",
            "last_notification_id": lastNotificationId ?? "nil",
            "notification_count": notificationCount,
            "error_message": errorMessage ?? "nil",
            "cookie_info": cookieInfo,
            "pending_background_tasks": pendingTasks.count,
            "notification_authorized": notificationManager.isAuthorized
        ]
    }
    
    // MARK: - Cleanup
    func cleanup() {
        stopTracking()
        notificationManager.clearNotificationHistory()
        cookieManager.clearStoredUserId()
        
        UserDefaults.standard.removeObject(forKey: trackingStateKey)
        print("📦 Order tracking cleanup completed")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        // Invalidate timer on main thread
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
        }
    }
} 