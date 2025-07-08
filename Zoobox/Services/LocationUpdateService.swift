//
//  LocationUpdateService.swift
//  Zoobox
//
//  Created by omid on 27/06/2025.
//

import Foundation
import CoreLocation
import WebKit

/**
 # 📍 LocationUpdateService
 
 A comprehensive location tracking service that automatically posts user location updates
 to the API in various scenarios while respecting user permissions and privacy.
 
 ## Features:
 - ✅ Automatic triggers: App lifecycle, timer, WebView refresh
 - ✅ Privacy-first: Only operates with location permission and user_id cookie
 - ✅ Lazy initialization: Prevents premature permission dialogs
 - ✅ Accuracy validation: Only posts locations with < 50m accuracy
 - ✅ Real-time monitoring: Observable status and update counter
 
 ## Usage:
 ```swift
 // Service initializes automatically in AppDelegate
 // Manual trigger
 LocationUpdateService.shared.manualLocationUpdate()
 
 // Monitor status
 print(LocationUpdateService.shared.lastUpdateStatus)
 print("Updates sent: \(LocationUpdateService.shared.totalUpdatesSent)")
 ```
 
 ## API Integration:
 - Endpoint: https://mikmik.site/Location_updater.php
 - Method: POST (JSON)
 - Requirements: user_id cookie + location permission + accuracy < 50m
 
 For detailed documentation, see: LocationUpdateService-Documentation.md
 */
@MainActor
class LocationUpdateService: NSObject, ObservableObject {
    static let shared = LocationUpdateService()
    
    // MARK: - Properties
    private var locationManager: CLLocationManager?
    private let websiteDataStore = WKWebsiteDataStore.default()
    private let apiURL = "https://mikmik.site/Location_updater.php"
    
    // Timer management
    private var updateTimer: Timer?
    private var lastPostTime: Date?
    private let updateInterval: TimeInterval = 600 // 10 minutes
    
    // Location tracking
    private var currentLocation: CLLocation?
    private var isLocationServicesEnabled = false
    
    // Debug properties
    @Published var lastUpdateStatus: String = "Not started"
    @Published var totalUpdatesSent: Int = 0
    
    private override init() {
        super.init()
        // Don't initialize location manager here - defer until actually needed
        setupAppLifecycleObservers()
        setupTimer()
        print("📍 [LocationUpdateService] Service initialized")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        updateTimer?.invalidate()
        print("📍 [LocationUpdateService] Service deinitialized")
    }
    
    // MARK: - Setup Methods
    
    private func setupLocationManager() {
        if locationManager == nil {
            locationManager = CLLocationManager()
        }
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = 10.0 // Update every 10 meters
        print("📍 [LocationUpdateService] Location manager configured")
    }
    
    private func ensureLocationManagerInitialized() {
        if locationManager == nil {
            setupLocationManager()
        }
    }
    
    private func setupAppLifecycleObservers() {
        // App state change observers
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        // Device lock observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceWasLocked),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )
        
        print("📍 [LocationUpdateService] App lifecycle observers configured")
    }
    
    private func setupTimer() {
        // Start the 10-minute timer
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.postLocationUpdateIfNeeded(trigger: "10_minute_timer")
            }
        }
        print("📍 [LocationUpdateService] 10-minute timer configured")
    }
    
    // MARK: - App Lifecycle Event Handlers
    
    @objc private func appDidBecomeActive() {
        print("📍 [LocationUpdateService] App became active")
        Task {
            await postLocationUpdateIfNeeded(trigger: "app_became_active")
        }
    }
    
    @objc private func appWillResignActive() {
        print("📍 [LocationUpdateService] App will resign active")
        Task {
            await postLocationUpdateIfNeeded(trigger: "app_will_resign_active")
        }
    }
    
    @objc private func appDidEnterBackground() {
        print("📍 [LocationUpdateService] App entered background")
        Task {
            await postLocationUpdateIfNeeded(trigger: "app_entered_background")
        }
    }
    
    @objc private func appWillTerminate() {
        print("📍 [LocationUpdateService] App will terminate")
        Task {
            await postLocationUpdateIfNeeded(trigger: "app_will_terminate")
        }
    }
    
    @objc private func deviceWasLocked() {
        print("📍 [LocationUpdateService] Device was locked")
        Task {
            await postLocationUpdateIfNeeded(trigger: "device_locked")
        }
    }
    
    // MARK: - Public Methods
    
    /// Called when webview refreshes
    func onWebViewRefresh() {
        print("📍 [LocationUpdateService] WebView refresh detected")
        Task {
            await postLocationUpdateIfNeeded(trigger: "webview_refresh")
        }
    }
    
    /// Manual trigger for location update
    func manualLocationUpdate() {
        print("📍 [LocationUpdateService] Manual location update triggered")
        Task {
            await postLocationUpdateIfNeeded(trigger: "manual_trigger")
        }
    }
    
    /// Start location services
    func startLocationServices() {
        guard CLLocationManager.locationServicesEnabled() else {
            print("📍 [LocationUpdateService] Location services disabled")
            return
        }
        
        // Initialize location manager only when we actually need it
        ensureLocationManagerInitialized()
        
        let authStatus = CLLocationManager.authorizationStatus()
        switch authStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager?.startUpdatingLocation()
            isLocationServicesEnabled = true
            print("📍 [LocationUpdateService] Location services started")
        case .notDetermined:
            locationManager?.requestWhenInUseAuthorization()
            print("📍 [LocationUpdateService] Requesting location permission")
        default:
            isLocationServicesEnabled = false
            print("📍 [LocationUpdateService] Location permission denied")
        }
    }
    
    /// Stop location services
    func stopLocationServices() {
        locationManager?.stopUpdatingLocation()
        isLocationServicesEnabled = false
        print("📍 [LocationUpdateService] Location services stopped")
    }
    
    // MARK: - Core Location Update Logic
    
    private func postLocationUpdateIfNeeded(trigger: String) async {
        print("📍 [LocationUpdateService] =================================")
        print("📍 [LocationUpdateService] Location update triggered by: \(trigger)")
        print("📍 [LocationUpdateService] =================================")
        
        // FIXED: Apple Guideline 5.1.5 - App must be fully functional without location
        // Check if location permission is granted, but don't fail if not
        guard isLocationPermissionGranted() else {
            print("📍 [LocationUpdateService] ℹ️ Location permission not granted - skipping update (app continues normally)")
            lastUpdateStatus = "Location permission not granted (optional)"
            return
        }
        
        // Check if user_id cookie exists, but don't fail if not
        guard let userId = await extractUserIdFromCookies() else {
            print("📍 [LocationUpdateService] ℹ️ No user_id cookie found - skipping update (app continues normally)")
            lastUpdateStatus = "No user_id cookie (optional)"
            return
        }
        
        // Get current location, but don't fail if not available
        guard let location = await getCurrentLocation() else {
            print("📍 [LocationUpdateService] ℹ️ Could not get current location - skipping update (app continues normally)")
            lastUpdateStatus = "Location not available (optional)"
            return
        }
        
        // Check location accuracy, but don't fail if not accurate enough
        guard location.horizontalAccuracy < 50.0 else {
            print("📍 [LocationUpdateService] ℹ️ Location accuracy too low (\(location.horizontalAccuracy)m) - skipping update (app continues normally)")
            lastUpdateStatus = "Location accuracy too low (optional)"
            return
        }
        
        // Post location update - this is the only step that might actually fail
        await postLocationToAPI(location: location, userId: userId, trigger: trigger)
        
        // Update last post time
        lastPostTime = Date()
        print("📍 [LocationUpdateService] ✅ Location update completed for trigger: \(trigger)")
    }
    
    private func isLocationPermissionGranted() -> Bool {
        let authStatus = CLLocationManager.authorizationStatus()
        return authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways
    }
    
    private func extractUserIdFromCookies() async -> String? {
        do {
            let cookies = try await websiteDataStore.httpCookieStore.allCookies()
            
            // Look for user_id cookie for mikmik.site
            let userIdCookie = cookies.first { cookie in
                cookie.domain.contains("mikmik.site") && cookie.name == "user_id"
            }
            
            if let userIdCookie = userIdCookie {
                print("📍 [LocationUpdateService] Found user_id cookie: \(userIdCookie.value.prefix(10))...")
                return userIdCookie.value
            } else {
                print("📍 [LocationUpdateService] No user_id cookie found")
                return nil
            }
        } catch {
            print("📍 [LocationUpdateService] Error accessing cookies: \(error)")
            return nil
        }
    }
    
    private func getCurrentLocation() async -> CLLocation? {
        // If we have a recent location, use it
        if let current = currentLocation,
           Date().timeIntervalSince(current.timestamp) < 300 { // 5 minutes
            return current
        }
        
        // Otherwise, request a new location
        return await withCheckedContinuation { continuation in
            // Initialize location manager only when we actually need it
            ensureLocationManagerInitialized()
            
            guard let locationManager = locationManager else {
                print("📍 [LocationUpdateService] Failed to initialize location manager")
                continuation.resume(returning: nil)
                return
            }
            
            locationManager.requestLocation()
            
            // Set up a one-time location handler
            let handler = LocationHandler { [weak self] location, error in
                if let location = location {
                    self?.currentLocation = location
                    continuation.resume(returning: location)
                } else {
                    print("📍 [LocationUpdateService] Location error: \(error?.localizedDescription ?? "Unknown")")
                    continuation.resume(returning: nil)
                }
            }
            
            // Store handler temporarily
            self.pendingLocationHandler = handler
            
            // Timeout after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                if self?.pendingLocationHandler != nil {
                    self?.pendingLocationHandler = nil
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private var pendingLocationHandler: LocationHandler?
    
    private func postLocationToAPI(location: CLLocation, userId: String, trigger: String) async {
        print("📍 [LocationUpdateService] 🚀 POSTING LOCATION TO API")
        print("📍 [LocationUpdateService] user_id: \(userId.prefix(10))...")
        print("📍 [LocationUpdateService] latitude: \(location.coordinate.latitude)")
        print("📍 [LocationUpdateService] longitude: \(location.coordinate.longitude)")
        print("📍 [LocationUpdateService] accuracy: \(location.horizontalAccuracy)")
        print("📍 [LocationUpdateService] trigger: \(trigger)")
        
        guard let url = URL(string: apiURL) else {
            print("📍 [LocationUpdateService] ❌ Invalid API URL")
            lastUpdateStatus = "Invalid API URL"
            return
        }
        
        // Prepare request body as JSON (as per PHP API requirements)
        let requestBody = [
            "user_id": userId,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy
        ] as [String : Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("*", forHTTPHeaderField: "Access-Control-Allow-Origin")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📍 [LocationUpdateService] Response status: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📍 [LocationUpdateService] Response body: \(responseString)")
                    
                    // Parse response JSON
                    if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = jsonResponse["success"] as? Bool {
                            if success {
                                totalUpdatesSent += 1
                                lastUpdateStatus = "✅ Success (\(trigger))"
                                print("📍 [LocationUpdateService] ✅ Location update successful")
                            } else {
                                let message = jsonResponse["message"] as? String ?? "Unknown error"
                                lastUpdateStatus = "❌ API Error: \(message)"
                                print("📍 [LocationUpdateService] ❌ API Error: \(message)")
                            }
                        }
                    }
                }
            }
        } catch {
            print("📍 [LocationUpdateService] ❌ Network error: \(error)")
            lastUpdateStatus = "Network error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Debug Methods
    
    func getDebugInfo() async -> [String: Any] {
        let userId = await extractUserIdFromCookies()
        let authStatus = CLLocationManager.authorizationStatus()
        
        return [
            "location_permission": authStatus.rawValue,
            "location_services_enabled": isLocationServicesEnabled,
            "user_id": userId?.prefix(10) ?? "nil",
            "current_location": currentLocation?.coordinate.latitude ?? 0.0,
            "last_update_status": lastUpdateStatus,
            "total_updates_sent": totalUpdatesSent,
            "last_post_time": lastPostTime?.description ?? "nil",
            "update_interval": updateInterval,
            "api_url": apiURL
        ]
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationUpdateService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
            print("📍 [LocationUpdateService] Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Call the pending handler if it exists
            pendingLocationHandler?.handle(location: location, error: nil)
            pendingLocationHandler = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 [LocationUpdateService] Location error: \(error.localizedDescription)")
        
        // Call the pending handler if it exists
        pendingLocationHandler?.handle(location: nil, error: error)
        pendingLocationHandler = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 [LocationUpdateService] Authorization changed: \(status.rawValue)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // Only start if we have permission AND we're past onboarding
            if manager == locationManager {
                manager.startUpdatingLocation()
                isLocationServicesEnabled = true
                print("📍 [LocationUpdateService] Location services started after authorization")
            }
        case .denied, .restricted:
            stopLocationServices()
        case .notDetermined:
            // Don't request permission here - let the onboarding flow handle it
            print("📍 [LocationUpdateService] Location permission not determined")
        @unknown default:
            break
        }
    }
}

// MARK: - Helper Classes
private class LocationHandler {
    private let completion: (CLLocation?, Error?) -> Void
    
    init(completion: @escaping (CLLocation?, Error?) -> Void) {
        self.completion = completion
    }
    
    func handle(location: CLLocation?, error: Error?) {
        completion(location, error)
    }
} 