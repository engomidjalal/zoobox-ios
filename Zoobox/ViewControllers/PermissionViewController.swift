import UIKit
import CoreLocation
import AVFoundation
import UserNotifications

class PermissionViewController: UIViewController, CLLocationManagerDelegate, PermissionManagerDelegate {
    
    private let locationManager = CLLocationManager()
    private let permissionManager = PermissionManager.shared
    private var cameraGranted = false
    private var notificationGranted = false
    private var locationGranted = false
    
    // Add flag to prevent repeated permission dialogs
    private var didDeferPermissions: Bool {
        get { UserDefaults.standard.bool(forKey: "didDeferPermissions") }
        set { UserDefaults.standard.set(newValue, forKey: "didDeferPermissions") }
    }
    
    // Add flag to prevent infinite loop
    private var hasProceededToMain = false
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Requesting Permissions..."
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        
        // Setup managers
        locationManager.delegate = self
        permissionManager.delegate = self
        
        // 🔍 Add debug info button
        setupDebugButton()
        
        // 🔍 Test permissions status first
        debugPermissionStatus()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Ensure we're on the main thread and view is in hierarchy
        DispatchQueue.main.async { [weak self] in
            self?.checkAndRequestPermissions()
        }
    }
    
    private func setupUI() {
        view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }
    
    // 🔍 DEBUG: Add debug button for testing
    private func setupDebugButton() {
        let debugButton = UIButton(type: .system)
        debugButton.setTitle("Debug Permissions", for: .normal)
        debugButton.backgroundColor = UIColor.systemBlue
        debugButton.setTitleColor(.white, for: .normal)
        debugButton.layer.cornerRadius = 8
        debugButton.addTarget(self, action: #selector(debugButtonTapped), for: .touchUpInside)
        
        view.addSubview(debugButton)
        debugButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            debugButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            debugButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            debugButton.heightAnchor.constraint(equalToConstant: 50),
            debugButton.widthAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    @objc private func debugButtonTapped() {
        debugPermissionStatus()
        showDetailedDebugAlert()
    }
    
    // 🔍 DEBUG: Check all permission statuses
    private func debugPermissionStatus() {
        let separator = String(repeating: "=", count: 50)
        print("\n" + separator)
        print("🔍 PERMISSION DEBUG REPORT")
        print(separator)
        print("📅 Timestamp: \(Date())")
        print("👤 User: engomidjalal")
        
        // Location
        let locationStatus = permissionManager.getPermissionStatus(for: .location)
        print("📍 Location Status: \(locationStatusString(locationStatus)) (Raw: \(locationStatus.rawValue))")
        print("📍 Location Services Enabled: \(CLLocationManager.locationServicesEnabled())")
        
        // Camera
        let cameraStatus = permissionManager.getPermissionStatus(for: .camera)
        print("📷 Camera Status: \(cameraStatusString(cameraStatus)) (Raw: \(cameraStatus.rawValue))")
        
        // Notifications
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                print("🔔 Notification Status: \(self.notificationStatusString(settings.authorizationStatus)) (Raw: \(settings.authorizationStatus.rawValue))")
                print("🔔 Alert Setting: \(settings.alertSetting.rawValue)")
                print("🔔 Badge Setting: \(settings.badgeSetting.rawValue)")
                print("🔔 Sound Setting: \(settings.soundSetting.rawValue)")
                print(separator + "\n")
            }
        }
    }
    
    // 🔍 DEBUG: Helper functions for readable status
    private func locationStatusString(_ status: PermissionStatus) -> String {
        switch status {
        case .notDetermined: return "NOT DETERMINED ⚪️"
        case .denied: return "DENIED ❌"
        case .restricted: return "RESTRICTED ⚠️"
        case .granted: return "GRANTED ✅"
        }
    }
    
    private func cameraStatusString(_ status: PermissionStatus) -> String {
        switch status {
        case .notDetermined: return "NOT DETERMINED ⚪️"
        case .denied: return "DENIED ❌"
        case .restricted: return "RESTRICTED ⚠️"
        case .granted: return "GRANTED ✅"
        }
    }
    
    private func notificationStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "NOT DETERMINED ⚪️"
        case .denied: return "DENIED ❌"
        case .authorized: return "AUTHORIZED ✅"
        case .provisional: return "PROVISIONAL ⚡️"
        case .ephemeral: return "EPHEMERAL 🔄"
        @unknown default: return "UNKNOWN ❓"
        }
    }
    
    // 🔍 DEBUG: Show detailed alert with current status
    private func showDetailedDebugAlert() {
        let locationStatus = permissionManager.getPermissionStatus(for: .location)
        let cameraStatus = permissionManager.getPermissionStatus(for: .camera)
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let message = """
                📍 Location: \(self.locationStatusString(locationStatus))
                📷 Camera: \(self.cameraStatusString(cameraStatus))
                🔔 Notifications: \(self.notificationStatusString(settings.authorizationStatus))
                
                📱 Device: \(UIDevice.current.name)
                📋 iOS: \(UIDevice.current.systemVersion)
                """
                
                let alert = UIAlertController(title: "🔍 Permission Debug", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Reset & Request Again", style: .default) { _ in
                    self.didDeferPermissions = false  // Reset deferred flag
                    self.forceRequestAllPermissions()
                })
                alert.addAction(UIAlertAction(title: "Clear Deferred Flag", style: .default) { _ in
                    self.didDeferPermissions = false
                    print("🔄 Deferred flag cleared - will show permission dialog again")
                })
                alert.addAction(UIAlertAction(title: "Go to Settings", style: .default) { _ in
                    self.openSettings()
                })
                alert.addAction(UIAlertAction(title: "Close", style: .cancel))
                self.present(alert, animated: true)
            }
        }
    }
    
    private func requestAllPermissions() {
        print("🚀 Starting permission request flow...")
        statusLabel.text = "Requesting Location Permission..."
        requestLocationPermission()
    }
    
    // 🔍 DEBUG: Enhanced location permission request
    private func requestLocationPermission() {
        let status = permissionManager.getPermissionStatus(for: .location)
        
        print("\n📍 LOCATION PERMISSION REQUEST")
        print("Current status: \(locationStatusString(status))")
        print("Location services enabled: \(CLLocationManager.locationServicesEnabled())")
        
        if status == .notDetermined {
            print("✅ Status is notDetermined - requesting authorization")
            print("📱 Calling locationManager.requestWhenInUseAuthorization()...")
            locationManager.requestWhenInUseAuthorization()
        } else {
            print("⚠️ Status already determined - skipping request")
            locationGranted = status.isGranted
            print("Location granted: \(locationGranted)")
            DispatchQueue.main.async {
                self.requestCameraPermission()
            }
        }
    }
    
    // 🔍 DEBUG: Enhanced delegate callback
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("\n🔄 LOCATION AUTHORIZATION CHANGED")
        print("New status: \(locationStatusString(permissionManager.getPermissionStatus(for: .location)))")
        
        locationGranted = (status == .authorizedAlways || status == .authorizedWhenInUse)
        print("Location granted: \(locationGranted)")
        
        if status == .authorizedWhenInUse {
            print("✅ Got when-in-use, proceeding to camera")
            DispatchQueue.main.async {
                self.requestCameraPermission()
            }
        } else if status == .authorizedAlways {
            print("✅ Got always authorization, proceeding to camera")
            DispatchQueue.main.async {
                self.requestCameraPermission()
            }
        } else if status == .denied || status == .restricted {
            print("❌ Location denied/restricted, proceeding to camera anyway")
            locationGranted = false
            DispatchQueue.main.async {
                self.requestCameraPermission()
            }
        }
    }
    
    // 🔍 DEBUG: Enhanced camera permission request
    private func requestCameraPermission() {
        let status = permissionManager.getPermissionStatus(for: .camera)
        
        print("\n📷 CAMERA PERMISSION REQUEST")
        print("Current status: \(cameraStatusString(status))")
        
        statusLabel.text = "Requesting Camera Permission..."
        
        switch status {
        case .notDetermined:
            print("✅ Status is notDetermined - requesting access")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                print("📷 Camera access result: \(granted)")
                self.cameraGranted = granted
                DispatchQueue.main.async {
                    self.requestNotificationPermission()
                }
            }
        case .granted:
            print("✅ Camera already authorized")
            cameraGranted = true
            requestNotificationPermission()
        default:
            print("❌ Camera denied/restricted")
            cameraGranted = false
            requestNotificationPermission()
        }
    }
    
    // 🔍 DEBUG: Enhanced notification permission request
    private func requestNotificationPermission() {
        statusLabel.text = "Requesting Notification Permission..."
        
        print("\n🔔 NOTIFICATION PERMISSION REQUEST")
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Current status: \(self.notificationStatusString(settings.authorizationStatus))")
            
            switch settings.authorizationStatus {
            case .notDetermined:
                print("✅ Status is notDetermined - requesting authorization")
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    print("🔔 Notification access result: \(granted)")
                    if let error = error {
                        print("🔔 Notification error: \(error)")
                    }
                    self.notificationGranted = granted
                    DispatchQueue.main.async {
                        self.finishPermissionsFlow()
                    }
                }
            case .authorized, .provisional:
                print("✅ Notifications already authorized")
                self.notificationGranted = true
                DispatchQueue.main.async {
                    self.finishPermissionsFlow()
                }
            default:
                print("❌ Notifications denied")
                self.notificationGranted = false
                DispatchQueue.main.async {
                    self.finishPermissionsFlow()
                }
            }
        }
    }
    
    // 🔍 DEBUG: Enhanced finish flow
    private func finishPermissionsFlow() {
        print("\n🏁 PERMISSION FLOW COMPLETE")
        print("Location: \(locationGranted ? "✅" : "❌")")
        print("Camera: \(cameraGranted ? "✅" : "❌")")
        print("Notifications: \(notificationGranted ? "✅" : "❌")")
        
        if locationGranted && cameraGranted && notificationGranted {
            statusLabel.text = "All permissions granted! ✅\nProceeding..."
            print("🎉 All permissions granted - proceeding to main app")
            // Clear deferred flag since permissions are now granted
            didDeferPermissions = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.proceedToMain()
            }
        } else {
            let missingPermissions = [
                !locationGranted ? "Location" : nil,
                !cameraGranted ? "Camera" : nil,
                !notificationGranted ? "Notifications" : nil
            ].compactMap { $0 }
            
            statusLabel.text = "Missing: \(missingPermissions.joined(separator: ", "))\nPlease enable in Settings."
            print("⚠️ Missing permissions: \(missingPermissions)")
            
            showPermissionMissingAlert()
        }
    }
    
    private func showPermissionMissingAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Permissions Required",
                message: "Zoobox needs Location, Camera, and Notification permissions to work properly.\nPlease enable them in Settings.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
                self.openSettings()
            }))
            alert.addAction(UIAlertAction(title: "Retry", style: .cancel, handler: { _ in
                self.requestAllPermissions()
            }))
            self.present(alert, animated: true)
        }
    }
    
    // MARK: - PermissionManagerDelegate
    
    func permissionManager(_ manager: PermissionManager, didUpdatePermissions permissions: [PermissionType: PermissionStatus]) {
        // Update local permission status
        locationGranted = permissions[.location]?.isGranted ?? false
        cameraGranted = permissions[.camera]?.isGranted ?? false
        notificationGranted = permissions[.notifications]?.isGranted ?? false
        
        print("🔐 PermissionManager updated permissions:")
        print("Location: \(locationGranted ? "✅" : "❌")")
        print("Camera: \(cameraGranted ? "✅" : "❌")")
        print("Notifications: \(notificationGranted ? "✅" : "❌")")
    }
    
    func permissionManager(_ manager: PermissionManager, requiresPermissionAlertFor permission: PermissionType) {
        // Handle permission alert when no view controller is available
        showPermissionAlert(for: permission)
    }
    
    private func showPermissionAlert(for permission: PermissionType) {
        let alert = UIAlertController(
            title: "\(permission.displayName) Permission Required",
            message: "Please enable \(permission.displayName.lowercased()) permissions in Settings to use this feature.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // 🔍 DEBUG: Force request all permissions (for testing)
    private func forceRequestAllPermissions() {
        print("🔄 FORCE REQUESTING ALL PERMISSIONS")
        
        // Use PermissionManager to request all permissions
        for permissionType in PermissionType.allCases {
            permissionManager.requestPermission(for: permissionType, from: self)
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func proceedToMain() {
        // Prevent multiple calls
        guard !hasProceededToMain else {
            print("🚫 Already proceeding to main - preventing duplicate calls")
            return
        }
        
        hasProceededToMain = true
        print("🚀 Proceeding to main app...")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let mainVC = MainViewController()
            mainVC.modalPresentationStyle = .fullScreen
            mainVC.modalTransitionStyle = .crossDissolve
            
            self.present(mainVC, animated: true) {
                // Clean up any references and dismiss this view controller
                print("✅ MainViewController presented successfully")
                self.dismiss(animated: false) {
                    print("✅ PermissionViewController dismissed")
                }
            }
        }
    }
    
    private func checkAndRequestPermissions() {
        // Prevent infinite loop
        guard !hasProceededToMain else {
            print("🚫 Already proceeded to main - preventing infinite loop")
            return
        }
        
        // Check if we're still the top view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let topViewController = window.rootViewController?.topMostViewController(),
              topViewController == self else {
            print("🚫 Not the top view controller - skipping")
            return
        }
        
        // Check if user previously deferred permissions
        if didDeferPermissions {
            print("⏭️ User previously deferred permissions - proceeding to main")
            proceedToMain()
            return
        }
        
        // Check current permission status
        let locationStatus = PermissionManager.shared.getPermissionStatus(for: .location)
        let cameraStatus = PermissionManager.shared.getPermissionStatus(for: .camera)
        let notificationStatus = PermissionManager.shared.getPermissionStatus(for: .notifications)
        
        print("🔍 Current permission status:")
        print("   Location: \(locationStatus)")
        print("   Camera: \(cameraStatus)")
        print("   Notifications: \(notificationStatus)")
        
        // If all permissions are granted, proceed to main
        if locationStatus == .granted && cameraStatus == .granted && notificationStatus == .granted {
            print("🎉 All permissions already granted - proceeding to main app")
            proceedToMain()
            return
        }
        
        // Show permission request UI
        showPermissionRequestUI()
    }
    
    private func showPermissionRequestUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create and show the permission request UI
            let alert = UIAlertController(
                title: "Permissions Required",
                message: "This app needs access to location, camera, and notifications to function properly.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Grant Permissions", style: .default) { _ in
                self.requestAllPermissions()
            })
            
            alert.addAction(UIAlertAction(title: "Later", style: .cancel) { _ in
                // User chose to skip permissions for now - set flag to prevent re-prompting
                self.didDeferPermissions = true
                print("⏭️ User chose 'Later' - setting deferred flag")
                self.proceedToMain()
            })
            
            self.present(alert, animated: true)
        }
    }
}

// MARK: - UIViewController Extension
extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController() ?? navigation
        }
        
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        
        return self
    }
}


