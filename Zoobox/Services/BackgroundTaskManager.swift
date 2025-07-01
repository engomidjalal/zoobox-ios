//
//  BackgroundTaskManager.swift
//  Zoobox
//
//  Created by omid on 27/06/2025.
//

import Foundation
import BackgroundTasks
import UIKit

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private let scheduler = BGTaskScheduler.shared
    private var isRegistered = false
    
    private init() {}
    
    // MARK: - Background Task Registration
    func registerBackgroundTasks() {
        guard !isRegistered else {
            print("🔄 Background tasks already registered")
            return
        }
        
        do {
            // Register app refresh task (for frequent updates)
            try scheduler.register(
                forTaskWithIdentifier: BackgroundTaskConfig.refreshTaskIdentifier,
                using: nil
            ) { task in
                self.handleAppRefreshTask(task as! BGAppRefreshTask)
            }
            
            // Register processing task (for longer operations)
            try scheduler.register(
                forTaskWithIdentifier: BackgroundTaskConfig.processingTaskIdentifier,
                using: nil
            ) { task in
                self.handleProcessingTask(task as! BGProcessingTask)
            }
            
            isRegistered = true
            print("🔄 Background tasks registered successfully")
            
        } catch {
            print("🔄 Failed to register background tasks: \(error)")
        }
    }
    
    // MARK: - Task Scheduling
    func scheduleBackgroundTasks() {
        scheduleAppRefreshTask()
        scheduleProcessingTask()
    }
    
    private func scheduleAppRefreshTask() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskConfig.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15)
        
        do {
            try scheduler.submit(request)
            print("🔄 App refresh task scheduled for 15 seconds")
        } catch {
            print("🔄 Failed to schedule app refresh task: \(error)")
        }
    }
    
    private func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: BackgroundTaskConfig.processingTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try scheduler.submit(request)
            print("🔄 Processing task scheduled for 15 seconds")
        } catch {
            print("🔄 Failed to schedule processing task: \(error)")
        }
    }
    
    // MARK: - Task Handlers
    private func handleAppRefreshTask(_ task: BGAppRefreshTask) {
        print("🔄 App refresh task started")
        
        // Set up task expiration handler
        task.expirationHandler = {
            print("🔄 App refresh task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Perform the background work
        Task {
            do {
                try await performOrderTracking()
                
                // Schedule the next refresh
                scheduleAppRefreshTask()
                
                // Mark task as completed
                task.setTaskCompleted(success: true)
                print("🔄 App refresh task completed successfully")
                
            } catch {
                print("🔄 App refresh task failed: \(error)")
                task.setTaskCompleted(success: false)
                
                // Schedule retry with longer interval
                scheduleRetryTask()
            }
        }
    }
    
    private func handleProcessingTask(_ task: BGProcessingTask) {
        print("🔄 Processing task started")
        
        // Set up task expiration handler
        task.expirationHandler = {
            print("🔄 Processing task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Perform the background work
        Task {
            do {
                try await performOrderTracking()
                
                // Schedule the next processing task
                scheduleProcessingTask()
                
                // Mark task as completed
                task.setTaskCompleted(success: true)
                print("🔄 Processing task completed successfully")
                
            } catch {
                print("🔄 Processing task failed: \(error)")
                task.setTaskCompleted(success: false)
                
                // Schedule retry with longer interval
                scheduleRetryTask()
            }
        }
    }
    
    // MARK: - Order Tracking Work
    private func performOrderTracking() async throws {
        // Get user ID from cookie manager
        guard let userId = await OrderTrackingCookieManager.shared.getUserId() else {
            throw OrderTrackingError.noUserId
        }
        
        // Check for new orders
        let response = try await OrderTrackingAPIClient.shared.checkOrdersWithRetry(userId: userId)
        
        if response.success && response.count > 0 {
            print("🔄 Found \(response.count) new notifications")
            
            // Schedule notifications for new orders
            await OrderNotificationManager.shared.scheduleBatchNotifications(for: response.notifications)
            
            // Update tracking state
            await OrderTrackingService.shared.updateTrackingState(
                lastUpdateTime: Date(),
                lastNotificationId: response.notifications.last?.id
            )
        } else {
            print("🔄 No new notifications found")
        }
    }
    
    // MARK: - Retry Logic
    private func scheduleRetryTask() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskConfig.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15)
        
        do {
            try scheduler.submit(request)
            print("🔄 Fallback task scheduled for 15 seconds")
        } catch {
            print("🔄 Failed to schedule retry task: \(error)")
        }
    }
    
    // MARK: - Task Management
    func cancelAllBackgroundTasks() {
        scheduler.cancelAllTaskRequests()
        print("🔄 All background tasks cancelled")
    }
    
    func cancelTask(withIdentifier identifier: String) {
        scheduler.cancel(taskRequestWithIdentifier: identifier)
        print("🔄 Background task cancelled: \(identifier)")
    }
    
    func getPendingTasks() async -> [BGTaskRequest] {
        return await scheduler.pendingTaskRequests()
    }
    
    // MARK: - App State Handling
    func handleAppDidEnterBackground() {
        print("🔄 App entered background - scheduling tasks")
        scheduleBackgroundTasks()
    }
    
    func handleAppWillEnterForeground() {
        print("🔄 App will enter foreground - cancelling background tasks")
        cancelAllBackgroundTasks()
    }
    
    func handleAppWillTerminate() {
        print("🔄 App will terminate - ensuring tasks are scheduled")
        scheduleBackgroundTasks()
    }
} 