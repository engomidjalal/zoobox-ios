import UIKit
import WebKit
import CoreLocation
import MobileCoreServices
import SwiftUI

class MainViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, LocationManagerDelegate, PermissionManagerDelegate, ConnectivityManagerDelegate, ErrorViewControllerDelegate {
    // MARK: - Properties
    private var webView: WKWebView!
    private var refreshControl: UIRefreshControl!
    private var currentErrorViewController: ErrorViewController?
    private var isShowingError = false
    private var lastError: Error?
    private var retryCount = 0
    private let maxRetryCount = 3
    private var hasInjectedPermissionScript = false
    private var fileUploadCompletionHandler: (([URL]?) -> Void)?
    
    // MARK: - Managers
    private let locationManager = LocationManager()
    private let permissionManager = PermissionManager()
    private let connectivityManager = ConnectivityManager()
    private let cookieManager = CookieManager()
    private let offlineContentManager = OfflineContentManager()
    private let orderTrackingService = OrderTrackingService.shared
    private let fcmTokenCookieManager = FCMTokenCookieManager.shared
    
    // MARK: - Haptic Feedback
    private let lightImpactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactFeedback = UIImpactFeedbackGenerator(style: .heavy)
    
    // MARK: - Order Tracking Integration
    // Backend tracking only - no UI elements needed
    
    // Connectivity monitoring
    private var connectivityAlert: UIAlertController?
    
    // Loading state
    private var isLoading = false
    private var loadingStartTime: Date?
    
    // MARK: - Error Handling Properties
    
    private var errorRetryTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .zooboxBackground
        setupLocationManager()
        setupPermissionManager()
        setupConnectivityManager()
        setupCookieManager()
        
        setupWebView()
        
        // Only setup backend order tracking (no UI)
        setupBackendOrderTracking()
        
        loadMainSite()
        prepareHapticFeedback()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("📦 MainViewController viewDidAppear")
        
        // Start monitoring connectivity
        connectivityManager.startMonitoring()
        
        // Ensure FCM token is saved as cookie when view appears
        fcmTokenCookieManager.forceSaveCurrentFCMTokenAsCookie()
        
        // Start order tracking if user is logged in - with delay to ensure view is fully loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            Task {
                await self?.startOrderTrackingIfNeeded()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop monitoring when leaving this view
        connectivityManager.stopMonitoring()
    }
    
    // MARK: - Order Tracking Setup
    private func setupBackendOrderTracking() {
        print("📦 Starting backend order tracking setup...")
        
        // Observe order tracking service changes with proper error handling
        setupKVOObservers()
        
        print("📦 Backend order tracking setup completed")
    }
    
    private func setupKVOObservers() {
        print("📦 Setting up backend order tracking...")
        
        // No UI updates needed - just backend tracking
        print("📦 Backend order tracking active")
    }
    
    private func updateOrderTrackingButtonAppearance() {
        // Removed - no UI needed for backend tracking
    }
    
    private func startOrderTrackingIfNeeded() async {
        do {
            // Check if user is logged in (has cookies)
            guard await OrderTrackingCookieManager.shared.validateCookies() else {
                print("📦 User not logged in, skipping order tracking")
                return
            }
            
            // Start order tracking if not already active
            if !orderTrackingService.isTracking {
                await orderTrackingService.startTracking()
                print("📦 Order tracking started successfully")
            } else {
                print("📦 Order tracking already active")
            }
        } catch {
            print("⚠️ Failed to start order tracking: \(error)")
        }
    }
    
    // MARK: - Public Methods for Order Tracking
    func loadURL(_ url: URL) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = .high
        locationManager.minimumDistanceFilter = 5.0
    }
    
    private func setupPermissionManager() {
        permissionManager.delegate = self
    }
    
    private func setupConnectivityManager() {
        connectivityManager.delegate = self
    }
    
    private func setupCookieManager() {
        // cookieManager.delegate = self
        
        // Listen for user login/logout notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidLogin),
            name: OrderTrackingCookieManager.userDidLoginNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidLogout),
            name: OrderTrackingCookieManager.userDidLogoutNotification,
            object: nil
        )
    }
    
    @objc private func userDidLogin(_ notification: Notification) {
        if let userId = notification.userInfo?["userId"] as? String {
            print("📦 User logged in notification received: \(userId)")
            
            // Ensure FCM token is saved as cookie when user logs in
            fcmTokenCookieManager.forceSaveCurrentFCMTokenAsCookie()
            
            Task {
                await startOrderTrackingIfNeeded()
            }
        }
    }
    
    @objc private func userDidLogout(_ notification: Notification) {
        if let userId = notification.userInfo?["userId"] as? String {
            print("📦 User logged out notification received: \(userId)")
            orderTrackingService.stopTracking()
        }
    }
    
    private func setupWebView() {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = WKWebsiteDataStore.default()
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webConfiguration.preferences.javaScriptEnabled = true
        
        // Note: We use JavaScript override to prevent browser permission dialogs
        // The configuration keys that were here were causing crashes
        
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "hapticFeedback")
        userContentController.add(self, name: "locationRequest")
        userContentController.add(self, name: "startRealTimeLocation")
        userContentController.add(self, name: "stopRealTimeLocation")
        userContentController.add(self, name: "injectLocation")
        userContentController.add(self, name: "nativeMessage")
        userContentController.add(self, name: "requestPermission")
        userContentController.add(self, name: "getPermissionStatus")
        userContentController.add(self, name: "connectionRestored")
        userContentController.add(self, name: "connectionLost")
        userContentController.add(self, name: "retryConnection")
        userContentController.add(self, name: "checkSettings")
        userContentController.add(self, name: "enableOfflineMode")
        
        // Enhanced JS bridge with permission handling
        let jsSource = """
            // Zoobox Permission Bridge
            window.ZooboxBridge = {
                // Request permission with explanation
                requestPermission: function(type) {
                    window.webkit.messageHandlers.requestPermission.postMessage({type: type});
                },
                
                // Get current permission status
                getPermissionStatus: function(type) {
                    window.webkit.messageHandlers.getPermissionStatus.postMessage({type: type});
                },
                
                // Check if permission is granted
                isPermissionGranted: function(type) {
                    return window.zooboxPermissions && window.zooboxPermissions[type] === 'granted';
                },
                
                // Get current location (if permission granted)
                getCurrentLocation: function() {
                    if (this.isPermissionGranted('location')) {
                        window.webkit.messageHandlers.locationRequest.postMessage({});
                    } else {
                        this.requestPermission('location');
                    }
                },
                
                // Haptic feedback
                hapticFeedback: function(type) {
                    window.webkit.messageHandlers.hapticFeedback.postMessage({type: type});
                }
            };
            
            // Initialize permissions object immediately
            window.zooboxPermissions = window.zooboxPermissions || {};
            
            // Listen for permission updates
            window.addEventListener('zooboxPermissionsUpdate', function(event) {
                console.log('🔐 Permissions updated:', event.detail);
                // Update the permissions object
                if (event.detail) {
                    window.zooboxPermissions = event.detail;
                }
                // Notify any waiting permission requests
                if (window.onZooboxPermissionUpdate) {
                    window.onZooboxPermissionUpdate(event.detail);
                }
            });
            
            console.log('🔐 ZooboxBridge initialized');
        """
        
        let script = WKUserScript(source: jsSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(script)
        
        // Add an even earlier script to immediately override geolocation API
        let earlyOverrideScript = """
            // IMMEDIATE geolocation override - runs before anything else
            console.log('🔐 IMMEDIATE geolocation override starting...');
            
            // Override geolocation API immediately if it exists
            if (navigator.geolocation) {
                const originalGetCurrentPosition = navigator.geolocation.getCurrentPosition;
                const originalWatchPosition = navigator.geolocation.watchPosition;
                
                navigator.geolocation.getCurrentPosition = function(successCallback, errorCallback, options) {
                    console.log('🔐 EARLY: Geolocation getCurrentPosition intercepted');
                    
                    // Check if we have permission (will be updated later)
                    if (window.zooboxPermissions && window.zooboxPermissions.location === 'granted') {
                        console.log('✅ EARLY: Permission granted, using native location');
                        if (window.ZooboxBridge && window.ZooboxBridge.getCurrentLocation) {
                            window.ZooboxBridge.getCurrentLocation();
                            window.lastLocationCallback = successCallback;
                            window.lastLocationErrorCallback = errorCallback;
                        } else {
                            // Fallback to original
                            originalGetCurrentPosition.call(navigator.geolocation, successCallback, errorCallback, options);
                        }
                    } else {
                        console.log('❌ EARLY: Permission not granted, requesting');
                        if (window.ZooboxBridge && window.ZooboxBridge.requestPermission) {
                            window.ZooboxBridge.requestPermission('location');
                        }
                        if (errorCallback) {
                            errorCallback({ code: 1, message: 'Permission denied' });
                        }
                    }
                };
                
                navigator.geolocation.watchPosition = function(successCallback, errorCallback, options) {
                    console.log('🔐 EARLY: Geolocation watchPosition intercepted');
                    
                    if (window.zooboxPermissions && window.zooboxPermissions.location === 'granted') {
                        console.log('✅ EARLY: Permission granted, starting native tracking');
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.startRealTimeLocation) {
                            window.webkit.messageHandlers.startRealTimeLocation.postMessage({});
                        }
                        window.locationWatchCallback = successCallback;
                        window.locationWatchErrorCallback = errorCallback;
                        return Math.floor(Math.random() * 1000000);
                    } else {
                        console.log('❌ EARLY: Permission not granted, requesting');
                        if (window.ZooboxBridge && window.ZooboxBridge.requestPermission) {
                            window.ZooboxBridge.requestPermission('location');
                        }
                        if (errorCallback) {
                            errorCallback({ code: 1, message: 'Permission denied' });
                        }
                        return -1;
                    }
                };
                
                console.log('✅ EARLY: Geolocation API overridden successfully');
            }
            
            // Initialize permissions object
            window.zooboxPermissions = window.zooboxPermissions || {};
            console.log('🔐 EARLY: Permission override complete');
        """
        
        let earlyScript = WKUserScript(source: earlyOverrideScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(earlyScript)
        
        webConfiguration.userContentController = userContentController
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Set a visible background color for debugging
        webView.backgroundColor = UIColor.white
        webView.isOpaque = true
        
        // Enable swipe-to-go-back gesture (iOS 7+)
        webView.allowsBackForwardNavigationGestures = true
        
        // Set up refresh control for webview
        refreshControl = UIRefreshControl()
        refreshControl.tintColor = .zooboxRed
        refreshControl.attributedTitle = NSAttributedString(
            string: "Pull to refresh",
            attributes: [
                .foregroundColor: UIColor.zooboxRed,
                .font: UIFont.systemFont(ofSize: 14, weight: .medium)
            ]
        )
        
        webView.scrollView.refreshControl = refreshControl
        
        // Set up pull-to-refresh
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        
        // Ensure FCM token cookie is available
        setupFCMTokenCookie()
        
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Pull to Refresh Setup (now handled by webview's built-in scroll view)
    
    @objc private func handleRefresh() {
        // Provide haptic feedback
        mediumImpactFeedback.impactOccurred()
        
        // Ensure spinner is red
        refreshControl.tintColor = .zooboxRed
        
        // Update refresh control title
        refreshControl.attributedTitle = NSAttributedString(
            string: "Refreshing...",
            attributes: [
                .foregroundColor: UIColor.zooboxRed,
                .font: UIFont.systemFont(ofSize: 14, weight: .medium)
            ]
        )
        
        // Reload the webview
        if let currentURL = webView.url {
            let request = URLRequest(url: currentURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
            webView.load(request)
        } else {
            loadMainSite()
        }
        
        // Hide error if showing
        hideError()
        
        // Reset retry count
        resetRetryCount()
    }
    
    // MARK: - Enhanced Pull to Refresh Features
    
    private func updateRefreshControlAppearance() {
        // Update refresh control with modern styling - red spinner
        refreshControl.tintColor = .zooboxRed
    }
    
    private func showRefreshSuccess() {
        // Provide success feedback
        lightImpactFeedback.impactOccurred()
        
        // Update refresh control title briefly
        refreshControl.attributedTitle = NSAttributedString(
            string: "Refreshed successfully",
            attributes: [
                .foregroundColor: UIColor.systemGreen,
                .font: UIFont.systemFont(ofSize: 14, weight: .medium)
            ]
        )
        
        // Reset title after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refreshControl.attributedTitle = NSAttributedString(
                string: "Pull to refresh",
                attributes: [
                    .foregroundColor: UIColor.secondaryLabel,
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium)
                ]
            )
        }
    }
    
    private func showRefreshError() {
        // Provide error feedback
        heavyImpactFeedback.impactOccurred()
        
        // Update refresh control title
        refreshControl.attributedTitle = NSAttributedString(
            string: "Refresh failed",
            attributes: [
                .foregroundColor: UIColor.systemRed,
                .font: UIFont.systemFont(ofSize: 14, weight: .medium)
            ]
        )
        
        // Reset title after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.refreshControl.attributedTitle = NSAttributedString(
                string: "Pull to refresh",
                attributes: [
                    .foregroundColor: UIColor.secondaryLabel,
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium)
                ]
            )
        }
    }
    
    private func prepareHapticFeedback() {
        lightImpactFeedback.prepare()
        mediumImpactFeedback.prepare()
        heavyImpactFeedback.prepare()
    }
    
    private func loadMainSite() {
        print("🌐 Loading main site...")
        
        // Restore cookies before loading the site
        webView.restoreCookies()
        
        if let url = URL(string: "https://mikmik.site") {
            print("🌐 Loading URL: \(url)")
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            print("❌ Failed to create URL for mikmik.site")
        }
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "hapticFeedback":
            handleHapticFeedback(message: message)
        case "locationRequest":
            handleLocationRequest()
        case "startRealTimeLocation":
            handleStartRealTimeLocation()
        case "stopRealTimeLocation":
            handleStopRealTimeLocation()
        case "injectLocation":
            handleInjectLocation()
        case "nativeMessage":
            handleNativeMessage(message: message)
        case "requestPermission":
            handleRequestPermission(message: message)
        case "getPermissionStatus":
            handleGetPermissionStatus(message: message)
        case "connectionRestored":
            handleConnectionRestored()
        case "connectionLost":
            handleConnectionLost()
        case "retryConnection":
            handleRetryConnection()
        case "checkSettings":
            handleCheckSettings()
        case "enableOfflineMode":
            handleEnableOfflineMode()
        default:
            break
        }
    }
    
    // MARK: - Permission Handlers
    
    private func handleRequestPermission(message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let permissionTypeString = body["type"] as? String,
              let permissionType = PermissionType(rawValue: permissionTypeString) else {
            print("🔐 Invalid permission request")
            return
        }
        
        print("🔐 WebView requesting permission: \(permissionType.displayName)")
        
        // Check if permission is already granted
        if permissionManager.isPermissionGranted(for: permissionType) {
            print("✅ Permission already granted for \(permissionType.displayName)")
            // Force refresh permissions to notify webview
            permissionManager.forceRefreshPermissionsInWebView(webView)
        } else {
            print("❌ Permission not granted for \(permissionType.displayName) - requesting")
            permissionManager.handleWebViewPermissionRequest(for: permissionType, from: self)
        }
    }
    
    private func handleGetPermissionStatus(message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let permissionTypeString = body["type"] as? String,
              let permissionType = PermissionType(rawValue: permissionTypeString) else {
            print("🔐 Invalid permission status request")
            return
        }
        
        let status = permissionManager.getPermissionStatus(for: permissionType)
        print("🔐 WebView requested permission status for \(permissionType.displayName): \(status.rawValue)")
        
        // Inject the specific permission status
        injectPermissionStatusToWebView(permissionType: permissionType, status: status)
        
        // Also force refresh all permissions to ensure consistency
        permissionManager.forceRefreshPermissionsInWebView(webView)
    }
    
    private func injectPermissionStatusToWebView(permissionType: PermissionType, status: PermissionStatus) {
        let jsCode = """
            if (window.zooboxPermissions) {
                window.zooboxPermissions['\(permissionType.rawValue)'] = '\(status.rawValue)';
            } else {
                window.zooboxPermissions = {'\(permissionType.rawValue)': '\(status.rawValue)'};
            }
            console.log('🔐 Permission status for \(permissionType.displayName): \(status.rawValue)');
        """
        
        webView.evaluateJavaScript(jsCode) { _, error in
            if let error = error {
                print("🔐 Error injecting permission status: \(error)")
            }
        }
    }
    
    private func handleHapticFeedback(message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        DispatchQueue.main.async {
            switch type {
            case "light":
                self.lightImpactFeedback.impactOccurred()
            case "medium":
                self.mediumImpactFeedback.impactOccurred()
            case "heavy":
                self.heavyImpactFeedback.impactOccurred()
            default:
                self.lightImpactFeedback.impactOccurred()
            }
        }
    }
    
    private func handleLocationRequest() {
        print("🔐 Location request received from WebView")
        
        // Check if location permission is granted
        if permissionManager.isPermissionGranted(for: .location) {
            print("✅ Location permission granted - getting location")
            // Permission already granted, get location directly
            locationManager.getCurrentLocation { [weak self] location, error in
                DispatchQueue.main.async {
                    if let location = location {
                        print("📍 Location obtained successfully: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                        self?.injectLocationToWebView(location: location)
                    } else if let error = error {
                        print("📍 Location error: \(error.localizedDescription)")
                        self?.injectLocationErrorToWebView(error: error)
                    }
                }
            }
        } else {
            print("❌ Location permission not granted - requesting permission")
            // Request permission with explanation
            permissionManager.requestPermissionWithExplanation(for: .location, from: self)
        }
    }
    
    private func handleNativeMessage(message: WKScriptMessage) {
        print("Received message from JavaScript: \(message.body)")
    }
    
    private func showLocationPermissionAlert() {
        let alert = UIAlertController(
            title: "Location Access Required",
            message: "This website needs location access. Please enable location services in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - Real-time Location Handlers
    private func handleStartRealTimeLocation() {
        // Check permission before starting
        if permissionManager.isPermissionGranted(for: .location) {
            locationManager.startRealTimeTracking(interval: 5.0)
        } else {
            permissionManager.requestPermissionWithExplanation(for: .location, from: self)
        }
    }
    
    private func handleStopRealTimeLocation() {
        locationManager.stopRealTimeTracking()
    }
    
    private func handleInjectLocation() {
        // Check permission before getting location
        if permissionManager.isPermissionGranted(for: .location) {
            locationManager.getCurrentLocation { [weak self] location, error in
                DispatchQueue.main.async {
                    if let location = location {
                        self?.injectLocationToWebView(location: location)
                    } else if let error = error {
                        print("🗺️ Failed to get location for injection: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            permissionManager.requestPermissionWithExplanation(for: .location, from: self)
        }
    }
    
    // MARK: - Inject Location to WebView
    private func injectLocationToWebView(location: CLLocation) {
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "altitudeAccuracy": location.verticalAccuracy,
            "heading": location.course,
            "speed": location.speed,
            "timestamp": location.timestamp.timeIntervalSince1970 * 1000
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: locationData),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        let jsCode = """
            window.currentLocation = \(jsonString);
            if (window.lastLocationCallback) {
                window.lastLocationCallback({
                    coords: {
                        latitude: \(location.coordinate.latitude),
                        longitude: \(location.coordinate.longitude),
                        accuracy: \(location.horizontalAccuracy),
                        altitude: \(location.altitude),
                        altitudeAccuracy: \(location.verticalAccuracy),
                        heading: \(location.course),
                        speed: \(location.speed)
                    },
                    timestamp: \(location.timestamp.timeIntervalSince1970 * 1000)
                });
            }
            if (window.locationWatchCallback) {
                window.locationWatchCallback({
                    coords: {
                        latitude: \(location.coordinate.latitude),
                        longitude: \(location.coordinate.longitude),
                        accuracy: \(location.horizontalAccuracy),
                        altitude: \(location.altitude),
                        altitudeAccuracy: \(location.verticalAccuracy),
                        heading: \(location.course),
                        speed: \(location.speed)
                    },
                    timestamp: \(location.timestamp.timeIntervalSince1970 * 1000)
                });
            }
            window.dispatchEvent(new CustomEvent('nativeLocationUpdate', {
                detail: {
                    latitude: \(location.coordinate.latitude),
                    longitude: \(location.coordinate.longitude),
                    accuracy: \(location.horizontalAccuracy)
                }
            }));
            console.log('📍 Location injected:', \(location.coordinate.latitude), \(location.coordinate.longitude));
        """
        webView.evaluateJavaScript(jsCode) { _, error in
            if let error = error {
                print("🗺️ Error injecting location: \(error)")
            }
        }
    }
    private func injectLocationErrorToWebView(error: Error) {
        let jsCode = """
            if (window.lastLocationErrorCallback) {
                window.lastLocationErrorCallback({
                    error: '\(error.localizedDescription)'
                });
            }
            if (window.locationWatchErrorCallback) {
                window.locationWatchErrorCallback({
                    error: '\(error.localizedDescription)'
                });
            }
        """
        webView.evaluateJavaScript(jsCode, completionHandler: nil)
    }
    
    // MARK: - LocationManagerDelegate (All five methods)
    func locationManager(_ manager: LocationManager, didUpdateLocation location: CLLocation) {
        injectLocationToWebView(location: location)
        mediumImpactFeedback.impactOccurred()
    }
    func locationManager(_ manager: LocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
        heavyImpactFeedback.impactOccurred()
        injectLocationErrorToWebView(error: error)
    }
    func locationManager(_ manager: LocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.getCurrentLocation { [weak self] location, error in
                DispatchQueue.main.async {
                    if let location = location {
                        self?.injectLocationToWebView(location: location)
                    } else if let error = error {
                        self?.injectLocationErrorToWebView(error: error)
                    }
                }
            }
        case .denied, .restricted:
            showLocationPermissionAlert()
        default:
            break
        }
    }
    func locationManager(_ manager: LocationManager, didUpdateLocationStatus status: LocationStatus) {
        print("Location status updated: \(status)")
    }
    // ⭐️ Fifth required method
    func locationManagerRequiresPermissionAlert(_ manager: LocationManager) {
        showLocationPermissionAlert()
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("🌐 WebView started loading...")
        startLoading()
        lightImpactFeedback.impactOccurred()
        
        // Start timeout check
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.checkLoadingTimeout()
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("🌐 WebView finished loading successfully")
        stopLoading()
        mediumImpactFeedback.impactOccurred()
        
        // Stop refresh control
        refreshControl.endRefreshing()
        
        // Reset refresh control title
        refreshControl.attributedTitle = NSAttributedString(
            string: "Pull to refresh",
            attributes: [
                .foregroundColor: UIColor.secondaryLabel,
                .font: UIFont.systemFont(ofSize: 14, weight: .medium)
            ]
        )
        
        // Cache the page
        offlineContentManager.cacheCurrentPage(webView)
        
        // Backup cookies after page load
        if cookieManager.shouldBackupCookies() {
            webView.backupCookies()
        }
        
        // Ensure FCM token cookie is available after page load
        Task {
            if await fcmTokenCookieManager.validateFCMTokenCookie() {
                print("🔥 FCM token cookie validated after page load")
            } else {
                print("🔥 FCM token cookie missing after page load - refreshing")
                fcmTokenCookieManager.refreshFCMToken()
            }
            
            // Comprehensive verification of FCM token cookie status
            await fcmTokenCookieManager.verifyFCMTokenCookieStatus()
        }
        
        // Inject permissions to WebView FIRST - before any other scripts
        permissionManager.injectPermissionStatusToWebView(webView)
        
        // Only inject permission override script once
        guard !hasInjectedPermissionScript else {
            print("🔐 Permission override script already injected - skipping")
            return
        }
        
        hasInjectedPermissionScript = true
        print("🔐 Injecting permission override script...")
        
        // Inject permission override script
        webView.evaluateJavaScript("""
            console.log('🔐 Zoobox Permission Override System Initializing...');
            
            // Ensure permissions object exists
            if (!window.zooboxPermissions) {
                window.zooboxPermissions = {};
            }
            
            // Override geolocation API
            if (navigator.geolocation) {
                console.log('🔐 Overriding geolocation API...');
                
                navigator.geolocation.getCurrentPosition = function(successCallback, errorCallback, options) {
                    console.log('🔐 Geolocation getCurrentPosition called');
                    
                    if (window.zooboxPermissions.location === 'granted') {
                        console.log('✅ Location permission granted - using native location');
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.locationRequest) {
                            window.webkit.messageHandlers.locationRequest.postMessage({});
                        }
                    } else {
                        console.log('❌ Location permission not granted - requesting permission');
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.requestPermission) {
                            window.webkit.messageHandlers.requestPermission.postMessage({type: 'location'});
                        }
                        if (errorCallback) {
                            errorCallback({ code: 1, message: 'Permission denied' });
                        }
                    }
                };
                
                console.log('✅ Geolocation API overridden successfully');
            }
            
            // Override Notification API
            if (window.Notification) {
                console.log('🔐 Overriding Notification API...');
                
                window.Notification.requestPermission = function(callback) {
                    console.log('🔐 Notification permission requested');
                    
                    if (window.zooboxPermissions.notifications === 'granted') {
                        console.log('✅ Notification permission already granted');
                        if (callback) callback('granted');
                        return Promise.resolve('granted');
                    } else {
                        console.log('❌ Notification permission not granted - requesting permission');
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.requestPermission) {
                            window.webkit.messageHandlers.requestPermission.postMessage({type: 'notifications'});
                        }
                        if (callback) callback('denied');
                        return Promise.resolve('denied');
                    }
                };
                
                console.log('✅ Notification API overridden successfully');
            }
            
            console.log('🔐 Zoobox Permission Override System Initialized Successfully');
            console.log('🔐 Current permissions:', window.zooboxPermissions);
        """) { _, error in
            if let error = error {
                print("🔐 Error injecting permission override script: \(error)")
            } else {
                print("🔐 Permission override script injected successfully")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView failed to load: \(error.localizedDescription)")
        stopLoading()
        heavyImpactFeedback.impactOccurred()
        
        // Stop refresh control
        refreshControl.endRefreshing()
        
        // Show error feedback if this was a refresh
        if refreshControl.isRefreshing {
            showRefreshError()
        } else {
            // Reset refresh control title
            refreshControl.attributedTitle = NSAttributedString(
                string: "Pull to refresh",
                attributes: [
                    .foregroundColor: UIColor.secondaryLabel,
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium)
                ]
            )
        }
        
        handleWebViewError(error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView failed provisional navigation: \(error.localizedDescription)")
        stopLoading()
        heavyImpactFeedback.impactOccurred()
        
        // Stop refresh control
        refreshControl.endRefreshing()
        
        // Show error feedback if this was a refresh
        if refreshControl.isRefreshing {
            showRefreshError()
        } else {
            // Reset refresh control title
            refreshControl.attributedTitle = NSAttributedString(
                string: "Pull to refresh",
                attributes: [
                    .foregroundColor: UIColor.secondaryLabel,
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium)
                ]
            )
        }
        
        handleWebViewError(error)
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        // Handle redirects
        print("🔄 Server redirect detected")
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Handle authentication challenges
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
    
    // MARK: - WKUIDelegate (Camera & Photo File Upload)
    func webView(_ webView: WKWebView,
                 runOpenPanelWith parameters: Any,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping ([URL]?) -> Void) {
        
        // Check camera permission before showing picker
        if permissionManager.isPermissionGranted(for: .camera) {
            showFilePicker(completionHandler: completionHandler)
        } else {
            permissionManager.requestPermissionWithExplanation(for: .camera, from: self)
            completionHandler(nil)
        }
    }
    
    private func showFilePicker(completionHandler: @escaping ([URL]?) -> Void) {
        fileUploadCompletionHandler = completionHandler
        
        let alert = UIAlertController(title: "Upload Photo", message: "Choose a source", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
            self.presentImagePicker(sourceType: .camera)
        })
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
            self.presentImagePicker(sourceType: .photoLibrary)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completionHandler(nil)
        })
        self.present(alert, animated: true)
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            fileUploadCompletionHandler?(nil)
            return
        }
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        self.present(picker, animated: true)
    }
    
    // MARK: - WKUIDelegate (Geolocation Permission)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        // Check camera permissions
        switch type {
        case .camera:
            if permissionManager.isPermissionGranted(for: .camera) {
                decisionHandler(.grant)
            } else {
                permissionManager.requestPermissionWithExplanation(for: .camera, from: self)
                decisionHandler(.deny)
            }
        @unknown default:
            decisionHandler(.deny)
        }
    }
    
    func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
    
    // MARK: - WKUIDelegate (Geolocation Permission Override)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        print("🔐 WebView requesting geolocation permission for: \(origin.host)")
        
        // Always check if we have location permission first
        if permissionManager.isPermissionGranted(for: .location) {
            print("✅ Location permission already granted - allowing WebView access immediately")
            decisionHandler(.grant)
            return
        }
        
        // If we don't have permission, request it and deny for now
        // The permission manager will handle the request and update the webview later
        print("❌ Location permission not granted - requesting permission")
        permissionManager.requestPermissionWithExplanation(for: .location, from: self)
        
        // Deny for now, but the webview will be updated when permission is granted
        decisionHandler(.deny)
    }
    
    // MARK: - Error Handling Methods
    
    private func handleWebViewError(_ error: Error) {
        lastError = error
        let errorType = ErrorViewController.createErrorType(from: error)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showError(errorType, error: error)
        }
    }
    
    private func showError(_ errorType: ErrorType, error: Error) {
        let errorVC = ErrorViewController(errorType: errorType)
        errorVC.delegate = self
        addChild(errorVC)
        view.addSubview(errorVC.view)
        errorVC.didMove(toParent: self)
        
        errorVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            errorVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            errorVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        currentErrorViewController = errorVC
        isShowingError = true
    }
    
    private func hideError() {
        guard let errorVC = currentErrorViewController else { return }
        
        errorVC.willMove(toParent: nil)
        errorVC.view.removeFromSuperview()
        errorVC.removeFromParent()
        
        currentErrorViewController = nil
        isShowingError = false
        lastError = nil
    }
    
    // MARK: - Cookie Management Methods
    private func saveCookies() {
        webView.backupCookies()
    }
    
    private func loadSavedCookies() {
        webView.restoreCookies()
    }
    
    private func setupFCMTokenCookie() {
        // Ensure FCM token cookie is available
        Task {
            // Check if FCM token cookie exists
            if await fcmTokenCookieManager.validateFCMTokenCookie() {
                print("🔥 FCM token cookie is valid")
            } else {
                print("🔥 FCM token cookie not found - requesting new token")
                // Request new FCM token if cookie doesn't exist
                fcmTokenCookieManager.refreshFCMToken()
            }
        }
    }
    
    // MARK: - PermissionManagerDelegate
    
    func permissionManager(_ manager: PermissionManager, didUpdatePermissions permissions: [PermissionType: PermissionStatus]) {
        // Force refresh permissions in WebView to ensure they're properly updated
        permissionManager.forceRefreshPermissionsInWebView(webView)
        
        // If location permission was just granted, retry any pending geolocation requests
        if let locationStatus = permissions[.location], locationStatus == .granted {
            print("✅ Location permission granted - retrying any pending geolocation requests")
            
            // Inject a script to retry any pending geolocation requests
            let retryScript = """
                console.log('🔄 Retrying pending geolocation requests...');
                
                // If there are any pending location callbacks, retry them
                if (window.lastLocationCallback && window.zooboxPermissions.location === 'granted') {
                    console.log('🔄 Retrying getCurrentPosition request');
                    if (window.ZooboxBridge && window.ZooboxBridge.getCurrentLocation) {
                        window.ZooboxBridge.getCurrentLocation();
                    }
                }
                
                // If there are any pending watch callbacks, retry them
                if (window.locationWatchCallback && window.zooboxPermissions.location === 'granted') {
                    console.log('🔄 Retrying watchPosition request');
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.startRealTimeLocation) {
                        window.webkit.messageHandlers.startRealTimeLocation.postMessage({});
                    }
                }
            """
            
            webView.evaluateJavaScript(retryScript) { _, error in
                if let error = error {
                    print("🔐 Error retrying geolocation requests: \(error)")
                } else {
                    print("🔐 Geolocation requests retried successfully")
                }
            }
        }
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
    
    // MARK: - ConnectivityManagerDelegate
    
    func connectivityManager(_ manager: ConnectivityManager, didUpdateConnectivityStatus status: ConnectivityStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch status {
            case .connected:
                // Update refresh control for connected state
                self.updateRefreshControlForConnectivity(true)
                
                // Dismiss any connectivity alert if it exists
                if let alert = self.connectivityAlert {
                    alert.dismiss(animated: true) {
                        self.connectivityAlert = nil
                    }
                }
                
                // Hide any error views
                if self.isShowingError {
                    self.hideError()
                }
                
                // If we were trying to retry, now reload the page
                if self.retryCount > 0 {
                    self.resetRetryCount()
                    self.loadMainSite()
                }
                
                print("📡 Internet connection restored - auto-reloading")
                
            case .disconnected:
                // Update refresh control for disconnected state
                self.updateRefreshControlForConnectivity(false)
                
                // Show connectivity alert if not already showing
                if self.connectivityAlert == nil {
                    self.showConnectivityAlert()
                }
                print("📡 Internet connection lost")
                
            case .checking, .unknown:
                break
            }
        }
    }
    
    func connectivityManager(_ manager: ConnectivityManager, didUpdateGPSStatus enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !enabled {
                // Show GPS alert if disabled
                self.showGPSAlert()
            } else {
                // Dismiss GPS alert if it exists
                if let alert = self.connectivityAlert, alert.title?.contains("GPS") == true {
                    alert.dismiss(animated: true) {
                        self.connectivityAlert = nil
                    }
                }
            }
        }
    }
    
    private func showConnectivityAlert() {
        let alert = UIAlertController(
            title: "No Internet Connection",
            message: "Please check your Wi-Fi or cellular data connection.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: "App-Prefs:root=WIFI") {
                UIApplication.shared.open(url)
            } else if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
            // Immediately check connectivity and reload if available
            let connectivity = self.connectivityManager.checkConnectivity()
            if connectivity.isInternetConnected {
                // Test the actual connection before reloading
                self.testConnection { isWorking in
                    if isWorking {
                        self.loadMainSite()
                    } else {
                        // If still no connection, start retry process
                        self.retryLoading()
                    }
                }
            } else {
                // If still no connection, start retry process
                self.retryLoading()
            }
        })
        
        connectivityAlert = alert
        present(alert, animated: true)
    }
    
    private func showGPSAlert() {
        let alert = UIAlertController(
            title: "GPS Disabled",
            message: "Location services are required for this app to function properly.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        connectivityAlert = alert
        present(alert, animated: true)
    }
    
    // MARK: - ErrorViewControllerDelegate
    
    func errorViewControllerDidTapRetry(_ controller: ErrorViewController) {
        retryLoading()
    }
    
    func errorViewControllerDidTapSettings(_ controller: ErrorViewController) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    func errorViewControllerDidTapCheckConnection(_ controller: ErrorViewController) {
        connectivityManager.checkConnectivity()
    }
    
    // MARK: - Error Handling Methods
    
    private func retryLoading() {
        retryCount += 1
        print("🔄 Retry attempt \(retryCount)/\(maxRetryCount)")
        
        // Add a small delay to allow system to detect restored connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // First check if we have connectivity
            let connectivity = self.connectivityManager.checkConnectivity()
            print("📡 Connectivity check: GPS=\(connectivity.isGPSEnabled), Internet=\(connectivity.isInternetConnected)")
            
            if connectivity.isInternetConnected {
                // Test the actual connection before reloading
                print("🌐 Testing connection...")
                self.testConnection { isWorking in
                    print("🌐 Connection test result: \(isWorking)")
                    if isWorking {
                        // Connection is available, hide any error dialogs and reload
                        self.hideError()
                        self.loadMainSite()
                    } else {
                        // Connection test failed, show simple error
                        self.showSimpleNoInternetDialog()
                    }
                }
            } else {
                // Still no connection, show simple error
                self.showSimpleNoInternetDialog()
            }
        }
    }
    
    private func showSimpleNoInternetDialog() {
        let alert = UIAlertController(
            title: "No Internet Connection",
            message: "Please check your Wi-Fi or cellular data connection.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
            self.retryLoading()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Loading State Management
    
    private func startLoading() {
        isLoading = true
        loadingStartTime = Date()
        retryCount = 0
        hideError()
    }
    
    private func stopLoading() {
        isLoading = false
        loadingStartTime = nil
    }
    
    private func checkLoadingTimeout() {
        guard let startTime = loadingStartTime else { return }
        
        let timeout: TimeInterval = 30 // 30 seconds
        if Date().timeIntervalSince(startTime) > timeout {
            handleWebViewError(NSError(domain: "Timeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Loading timeout"]))
        }
    }
    
    // MARK: - Connection and Offline Handlers
    
    private func resetRetryCount() {
        retryCount = 0
        print("🔄 Retry count reset")
    }
    
    private func testConnection(completion: @escaping (Bool) -> Void) {
        // Test connection by trying to reach a reliable endpoint
        guard let url = URL(string: "https://www.apple.com") else {
            completion(false)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    completion(httpResponse.statusCode == 200)
                } else {
                    completion(error == nil)
                }
            }
        }
        task.resume()
    }
    
    private func handleConnectionRestored() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Reset retry count when connection is restored
            self.resetRetryCount()
            
            // Hide any error views
            if self.isShowingError {
                self.hideError()
            }
            
            print("🌐 Connection restored from JavaScript")
        }
    }
    
    private func handleConnectionLost() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Show simple error dialog
            self.showSimpleNoInternetDialog()
            
            print("📱 Connection lost from JavaScript")
        }
    }
    
    private func handleRetryConnection() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.retryLoading()
        }
    }
    
    private func handleCheckSettings() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func handleEnableOfflineMode() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.showSimpleNoInternetDialog()
        }
    }
    
    // MARK: - Programmatic Refresh
    
    func triggerRefresh() {
        // Programmatically trigger refresh
        refreshControl.beginRefreshing()
        handleRefresh()
    }
    
    // MARK: - Refresh Control State Management
    
    private func updateRefreshControlForConnectivity(_ isConnected: Bool) {
        if !isConnected {
            refreshControl.attributedTitle = NSAttributedString(
                string: "No internet connection",
                attributes: [
                    .foregroundColor: UIColor.systemOrange,
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium)
                ]
            )
            refreshControl.isEnabled = false
        } else {
            refreshControl.attributedTitle = NSAttributedString(
                string: "Pull to refresh",
                attributes: [
                    .foregroundColor: UIColor.secondaryLabel,
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium)
                ]
            )
            refreshControl.isEnabled = true
        }
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate
extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else {
            fileUploadCompletionHandler?(nil)
            return
        }
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
            fileUploadCompletionHandler?([fileURL])
        } else {
            fileUploadCompletionHandler?(nil)
        }
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        fileUploadCompletionHandler?(nil)
    }
}



