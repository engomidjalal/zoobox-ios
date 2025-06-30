import UIKit
import CoreLocation
import AVFoundation
import UserNotifications
import WebKit

protocol PermissionManagerDelegate: AnyObject {
    func permissionManager(_ manager: PermissionManager, didUpdatePermissions permissions: [PermissionType: PermissionStatus])
    func permissionManager(_ manager: PermissionManager, requiresPermissionAlertFor permission: PermissionType)
}

enum PermissionType: String, CaseIterable {
    case location = "location"
    case camera = "camera"
    case notifications = "notifications"
    
    var displayName: String {
        switch self {
        case .location: return "Location"
        case .camera: return "Camera"
        case .notifications: return "Notifications"
        }
    }
    
    var usageDescription: String {
        switch self {
        case .location: return "Zoobox needs your location to show nearby services and enable deliveries."
        case .camera: return "Zoobox needs camera access to scan QR codes and upload documents."
        case .notifications: return "Zoobox uses notifications to update you about orders and deliveries."
        }
    }
}

enum PermissionStatus: String {
    case notDetermined = "notDetermined"
    case denied = "denied"
    case restricted = "restricted"
    case granted = "granted"
    
    var isGranted: Bool {
        return self == .granted
    }
}

class PermissionManager: NSObject {
    static let shared = PermissionManager()
    
    weak var delegate: PermissionManagerDelegate?
    private let locationManager = CLLocationManager()
    
    private var permissionStatuses: [PermissionType: PermissionStatus] = [:]
    private var permissionAlertsShown: [PermissionType: Bool] = [:]
    
    override init() {
        super.init()
        setupLocationManager()
        updateAllPermissionStatuses()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
    }
    
    // MARK: - Public Methods
    
    func getPermissionStatus(for type: PermissionType) -> PermissionStatus {
        return permissionStatuses[type] ?? .notDetermined
    }
    
    func isPermissionGranted(for type: PermissionType) -> Bool {
        return getPermissionStatus(for: type).isGranted
    }
    
    func requestPermission(for type: PermissionType, from viewController: UIViewController? = nil) {
        let currentStatus = getPermissionStatus(for: type)
        
        switch currentStatus {
        case .notDetermined:
            requestPermissionDirectly(for: type)
        case .denied, .restricted:
            showPermissionDeniedAlert(for: type, from: viewController)
        case .granted:
            // Already granted, no action needed
            break
        }
    }
    
    func requestPermissionWithExplanation(for type: PermissionType, from viewController: UIViewController) {
        let currentStatus = getPermissionStatus(for: type)
        
        switch currentStatus {
        case .notDetermined:
            showPrePermissionAlert(for: type, from: viewController)
        case .denied, .restricted:
            showPermissionDeniedAlert(for: type, from: viewController)
        case .granted:
            // Already granted, no action needed
            break
        }
    }
    
    func updateAllPermissionStatuses() {
        // Update location and camera synchronously
        permissionStatuses[.location] = getCurrentPermissionStatus(for: .location)
        permissionStatuses[.camera] = getCurrentPermissionStatus(for: .camera)
        
        // Update notification status asynchronously
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                let notificationStatus: PermissionStatus
                switch settings.authorizationStatus {
                case .notDetermined: notificationStatus = .notDetermined
                case .denied: notificationStatus = .denied
                case .authorized, .provisional, .ephemeral: notificationStatus = .granted
                @unknown default: notificationStatus = .notDetermined
                }
                
                self?.permissionStatuses[.notifications] = notificationStatus
                self?.notifyDelegateOfPermissionChanges()
            }
        }
    }
    
    // MARK: - WebView Integration
    
    func injectPermissionStatusToWebView(_ webView: WKWebView) {
        let permissionData: [String: Any] = Dictionary(uniqueKeysWithValues: PermissionType.allCases.map { type in
            (type.rawValue, getPermissionStatus(for: type).rawValue)
        })
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: permissionData),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let jsCode = """
            // Update the permissions object
            window.zooboxPermissions = \(jsonString);
            
            // Dispatch permission update event
            window.dispatchEvent(new CustomEvent('zooboxPermissionsUpdate', {
                detail: \(jsonString)
            }));
            
            console.log('🔐 Zoobox permissions injected:', \(jsonString));
            console.log('🔐 Current permissions object:', window.zooboxPermissions);
        """
        
        webView.evaluateJavaScript(jsCode) { _, error in
            if let error = error {
                print("🔐 Error injecting permissions: \(error)")
            } else {
                print("🔐 Permissions injected successfully: \(jsonString)")
            }
        }
    }
    
    func forceRefreshPermissionsInWebView(_ webView: WKWebView) {
        // Force a complete refresh of permissions in the webview
        let permissionData: [String: Any] = Dictionary(uniqueKeysWithValues: PermissionType.allCases.map { type in
            (type.rawValue, getPermissionStatus(for: type).rawValue)
        })
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: permissionData),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let jsCode = """
            // Force refresh permissions
            window.zooboxPermissions = \(jsonString);
            
            // Force dispatch multiple events to ensure it's caught
            window.dispatchEvent(new CustomEvent('zooboxPermissionsUpdate', {
                detail: \(jsonString)
            }));
            
            // Also trigger a custom event for immediate update
            window.dispatchEvent(new CustomEvent('zooboxPermissionsForceUpdate', {
                detail: \(jsonString)
            }));
            
            console.log('🔐 Permissions force refreshed:', \(jsonString));
            
            // Notify any waiting callbacks
            if (window.onZooboxPermissionUpdate) {
                window.onZooboxPermissionUpdate(\(jsonString));
            }
        """
        
        webView.evaluateJavaScript(jsCode) { _, error in
            if let error = error {
                print("🔐 Error force refreshing permissions: \(error)")
            } else {
                print("🔐 Permissions force refreshed successfully")
            }
        }
    }
    
    func handleWebViewPermissionRequest(for type: PermissionType, from viewController: UIViewController) {
        if isPermissionGranted(for: type) {
            // Permission already granted, allow access
            allowWebViewAccess(for: type)
        } else {
            // Request permission with explanation
            requestPermissionWithExplanation(for: type, from: viewController)
        }
    }
    
    // MARK: - Private Methods
    
    private func getCurrentPermissionStatus(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .location:
            let status = CLLocationManager.authorizationStatus()
            switch status {
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            case .restricted: return .restricted
            case .authorizedWhenInUse, .authorizedAlways: return .granted
            @unknown default: return .notDetermined
            }
            
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .notDetermined: return .notDetermined
            case .denied: return .denied
            case .restricted: return .restricted
            case .authorized: return .granted
            @unknown default: return .notDetermined
            }
            
        case .notifications:
            // Return cached value, will be updated when notification permission is requested
            return permissionStatuses[.notifications] ?? .notDetermined
        }
    }
    
    func requestPermissionDirectly(for type: PermissionType) {
        // Reset alert shown flag to allow retry
        permissionAlertsShown[type] = false
        
        switch type {
        case .location:
            locationManager.requestWhenInUseAuthorization()
            
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionStatuses[.camera] = granted ? .granted : .denied
                    self?.notifyDelegateOfPermissionChanges()
                }
            }
            
        case .notifications:
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.permissionStatuses[.notifications] = granted ? .granted : .denied
                    self?.notifyDelegateOfPermissionChanges()
                }
            }
        }
    }
    
    private func showPrePermissionAlert(for type: PermissionType, from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "\(type.displayName) Access Needed",
            message: type.usageDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in
            self.requestPermissionDirectly(for: type)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        viewController.present(alert, animated: true)
    }
    
    private func showPermissionDeniedAlert(for type: PermissionType, from viewController: UIViewController?) {
        guard !(permissionAlertsShown[type] ?? false) else { return }
        permissionAlertsShown[type] = true
        
        let alert = UIAlertController(
            title: "\(type.displayName) Permission Required",
            message: "Please enable \(type.displayName.lowercased()) permissions in Settings to use this feature.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.permissionAlertsShown[type] = false
        })
        
        if let vc = viewController {
            vc.present(alert, animated: true)
        } else {
            delegate?.permissionManager(self, requiresPermissionAlertFor: type)
        }
    }
    
    private func allowWebViewAccess(for type: PermissionType) {
        // This method can be used to inject permission status or handle WebView access
        print("🔐 Allowing WebView access for \(type.displayName)")
    }
    
    private func notifyDelegateOfPermissionChanges() {
        delegate?.permissionManager(self, didUpdatePermissions: permissionStatuses)
    }
    
    func resetPermissionAlerts() {
        permissionAlertsShown.removeAll()
    }
    
    func canRetryPermission(for type: PermissionType) -> Bool {
        let status = getPermissionStatus(for: type)
        return status == .denied || status == .notDetermined
    }
    
    func areAllPermissionsGranted() -> Bool {
        return PermissionType.allCases.allSatisfy { isPermissionGranted(for: $0) }
    }
    
    func getDeniedPermissions() -> [PermissionType] {
        return PermissionType.allCases.filter { getPermissionStatus(for: $0) == .denied }
    }
    
    func getNotDeterminedPermissions() -> [PermissionType] {
        return PermissionType.allCases.filter { getPermissionStatus(for: $0) == .notDetermined }
    }
}

// MARK: - CLLocationManagerDelegate
extension PermissionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        let newStatus: PermissionStatus
        switch status {
        case .notDetermined: newStatus = .notDetermined
        case .denied: newStatus = .denied
        case .restricted: newStatus = .restricted
        case .authorizedWhenInUse, .authorizedAlways: newStatus = .granted
        @unknown default: newStatus = .notDetermined
        }
        
        permissionStatuses[.location] = newStatus
        notifyDelegateOfPermissionChanges()
    }
} 