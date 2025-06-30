import UIKit
import WebKit
import CoreLocation
import MobileCoreServices

class MainViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, LocationManagerDelegate, PermissionManagerDelegate, ConnectivityManagerDelegate, ErrorViewControllerDelegate {
    var webView: WKWebView!
    private let locationManager = LocationManager.shared
    private let permissionManager = PermissionManager.shared
    private let connectivityManager = ConnectivityManager.shared
    private let offlineContentManager = OfflineContentManager.shared
    private let lightImpactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactFeedback = UIImpactFeedbackGenerator(style: .heavy)
    
    // MARK: - Pull to Refresh
    private var refreshControl: UIRefreshControl!
    private var scrollView: UIScrollView!
    
    private var fileUploadCompletionHandler: (([URL]?) -> Void)?
    
    // Add flag to prevent multiple script injections
    private var hasInjectedPermissionScript = false
    
    // Connectivity monitoring
    private var connectivityAlert: UIAlertController?
    
    // Error handling
    private var currentErrorViewController: ErrorViewController?
    private var retryCount = 0
    private let maxRetryCount = 3
    
    // Loading state
    private var isLoading = false
    private var loadingStartTime: Date?
    
    // MARK: - Error Handling Properties
    
    private var lastError: Error?
    private var errorRetryTimer: Timer?
    private var isShowingError = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .zooboxBackground
        setupLocationManager()
        setupPermissionManager()
        setupConnectivityManager()
        setupWebView()
        loadMainSite()
        prepareHapticFeedback()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Start monitoring connectivity
        connectivityManager.startMonitoring()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop monitoring when leaving this view
        connectivityManager.stopMonitoring()
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
    
    private func setupWebView() {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = WKWebsiteDataStore.default()
        webConfiguration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webConfiguration.preferences.javaScriptEnabled = true
        
        // Configure geolocation permissions (removed invalid keys)
        // Note: allowFileAccessFromFileURLs and allowUniversalAccessFromFileURLs are not valid for WKPreferences
        
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
            
            // Listen for permission updates
            window.addEventListener('zooboxPermissionsUpdate', function(event) {
                console.log('🔐 Permissions updated:', event.detail);
                // Notify any waiting permission requests
                if (window.onZooboxPermissionUpdate) {
                    window.onZooboxPermissionUpdate(event.detail);
                }
            });
            
            console.log('🔐 ZooboxBridge initialized');
        """
        let userScript = WKUserScript(source: jsSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userContentController.addUserScript(userScript)
        webConfiguration.userContentController = userContentController
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Setup scroll view for pull-to-refresh
        setupScrollViewWithRefreshControl()
        
        view.addSubview(scrollView)
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor)
        ])
    }
    
    // MARK: - Pull to Refresh Setup
    private func setupScrollViewWithRefreshControl() {
        // Create scroll view
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .zooboxBackground
        
        // Create modern refresh control with red color
        refreshControl = UIRefreshControl()
        refreshControl.tintColor = .zooboxRed
        refreshControl.attributedTitle = NSAttributedString(
            string: "Pull to refresh",
            attributes: [
                .foregroundColor: UIColor.zooboxRed,
                .font: UIFont.systemFont(ofSize: 14, weight: .medium)
            ]
        )
        
        // Add refresh control to scroll view
        scrollView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        
        // Update refresh control appearance
        updateRefreshControlAppearance()
        
        // Add webview to scroll view
        scrollView.addSubview(webView)
        webView.backgroundColor = .zooboxBackground
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Make webview fill the entire scroll view
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            webView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            webView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }
    
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
        if let url = URL(string: "https://mikmik.site") {
            let request = URLRequest(url: url)
            webView.load(request)
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
        permissionManager.handleWebViewPermissionRequest(for: permissionType, from: self)
    }
    
    private func handleGetPermissionStatus(message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let permissionTypeString = body["type"] as? String,
              let permissionType = PermissionType(rawValue: permissionTypeString) else {
            print("🔐 Invalid permission status request")
            return
        }
        
        let status = permissionManager.getPermissionStatus(for: permissionType)
        injectPermissionStatusToWebView(permissionType: permissionType, status: status)
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
        // Check if location permission is granted
        if permissionManager.isPermissionGranted(for: .location) {
            // Permission already granted, get location directly
            locationManager.getCurrentLocation { [weak self] location, error in
                DispatchQueue.main.async {
                    if let location = location {
                        self?.injectLocationToWebView(location: location)
                    } else if let error = error {
                        self?.injectLocationErrorToWebView(error: error)
                    }
                }
            }
        } else {
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
        startLoading()
        lightImpactFeedback.impactOccurred()
        
        // Start timeout check
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.checkLoadingTimeout()
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        stopLoading()
        mediumImpactFeedback.impactOccurred()
        
        // Stop refresh control
        refreshControl.endRefreshing()
        
        // Show success feedback if this was a refresh
        if refreshControl.isRefreshing {
            showRefreshSuccess()
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
        
        // Cache the page
        offlineContentManager.cacheCurrentPage(webView)
        // Inject permissions to WebView
        permissionManager.injectPermissionStatusToWebView(webView)
        
        // Only inject permission override script once
        guard !hasInjectedPermissionScript else {
            print("🔐 Permission override script already injected - skipping")
            return
        }
        
        hasInjectedPermissionScript = true
        print("🔐 Injecting permission override script...")
        
        // Inject comprehensive permission override script
        let permissionOverrideScript = """
            console.log('Zoobox WebView loaded successfully');
            if (window.ZooboxBridge) {
                console.log('ZooboxBridge is available');
            }
            console.log('🔐 Available permissions:', window.zooboxPermissions);
            
            // Add offline detection
            window.addEventListener('online', function() {
                console.log('🌐 Internet connection restored');
                if (window.webkit && window.webkit.messageHandlers.connectionRestored) {
                    window.webkit.messageHandlers.connectionRestored.postMessage({});
                }
            });
            
            window.addEventListener('offline', function() {
                console.log('📱 Internet connection lost');
                if (window.webkit && window.webkit.messageHandlers.connectionLost) {
                    window.webkit.messageHandlers.connectionLost.postMessage({});
                }
            });
            
            // Comprehensive Permission Override System
            (function() {
                'use strict';
                
                // Store original APIs
                const originalGeolocation = navigator.geolocation;
                const originalNotification = window.Notification;
                const originalGetUserMedia = navigator.mediaDevices ? navigator.mediaDevices.getUserMedia : null;
                
                // Permission status from native app
                let zooboxPermissions = window.zooboxPermissions || {};
                
                // Override geolocation API
                if (navigator.geolocation) {
                    console.log('🔐 Overriding geolocation API...');
                    
                    const originalGetCurrentPosition = navigator.geolocation.getCurrentPosition;
                    const originalWatchPosition = navigator.geolocation.watchPosition;
                    const originalClearWatch = navigator.geolocation.clearWatch;
                    
                    // Override getCurrentPosition
                    navigator.geolocation.getCurrentPosition = function(successCallback, errorCallback, options) {
                        console.log('🔐 Geolocation getCurrentPosition called');
                        
                        if (zooboxPermissions.location === 'granted') {
                            console.log('✅ Location permission granted - using native location');
                            
                            if (window.ZooboxBridge && window.ZooboxBridge.getCurrentLocation) {
                                // Use native location
                                window.ZooboxBridge.getCurrentLocation();
                                
                                // Set up callbacks for native response
                                window.lastLocationCallback = function(position) {
                                    console.log('📍 Native location received:', position);
                                    if (successCallback) {
                                        successCallback(position);
                                    }
                                };
                                
                                window.lastLocationErrorCallback = function(error) {
                                    console.log('📍 Native location error:', error);
                                    if (errorCallback) {
                                        errorCallback(error);
                                    }
                                };
                            } else {
                                // Fallback to original API
                                console.log('⚠️ ZooboxBridge not available - using original API');
                                originalGetCurrentPosition.call(navigator.geolocation, successCallback, errorCallback, options);
                            }
                        } else {
                            console.log('❌ Location permission not granted - requesting permission');
                            if (window.ZooboxBridge && window.ZooboxBridge.requestPermission) {
                                window.ZooboxBridge.requestPermission('location');
                            }
                            if (errorCallback) {
                                errorCallback({ 
                                    code: 1, 
                                    message: 'Permission denied - please grant location permission in the app' 
                                });
                            }
                        }
                    };
                    
                    // Override watchPosition
                    navigator.geolocation.watchPosition = function(successCallback, errorCallback, options) {
                        console.log('🔐 Geolocation watchPosition called');
                        
                        if (zooboxPermissions.location === 'granted') {
                            console.log('✅ Location permission granted - starting native tracking');
                            
                            if (window.ZooboxBridge && window.ZooboxBridge.getCurrentLocation) {
                                // Start real-time tracking
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.startRealTimeLocation) {
                                    window.webkit.messageHandlers.startRealTimeLocation.postMessage({});
                                }
                                
                                // Set up callbacks for location updates
                                window.locationWatchCallback = function(position) {
                                    console.log('📍 Native location update:', position);
                                    if (successCallback) {
                                        successCallback(position);
                                    }
                                };
                                
                                window.locationWatchErrorCallback = function(error) {
                                    console.log('📍 Native location error:', error);
                                    if (errorCallback) {
                                        errorCallback(error);
                                    }
                                };
                                
                                // Return a mock watch ID
                                const watchId = Math.floor(Math.random() * 1000000);
                                console.log('📍 Watch ID created:', watchId);
                                return watchId;
                            } else {
                                // Fallback to original API
                                console.log('⚠️ ZooboxBridge not available - using original API');
                                return originalWatchPosition.call(navigator.geolocation, successCallback, errorCallback, options);
                            }
                        } else {
                            console.log('❌ Location permission not granted - requesting permission');
                            if (window.ZooboxBridge && window.ZooboxBridge.requestPermission) {
                                window.ZooboxBridge.requestPermission('location');
                            }
                            if (errorCallback) {
                                errorCallback({ 
                                    code: 1, 
                                    message: 'Permission denied - please grant location permission in the app' 
                                });
                            }
                            return -1;
                        }
                    };
                    
                    // Keep original clearWatch
                    navigator.geolocation.clearWatch = function(watchId) {
                        console.log('🔐 Clearing location watch:', watchId);
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.stopRealTimeLocation) {
                            window.webkit.messageHandlers.stopRealTimeLocation.postMessage({});
                        }
                        return originalClearWatch.call(navigator.geolocation, watchId);
                    };
                    
                    console.log('✅ Geolocation API overridden successfully');
                }
                
                // Override Notification API
                if (window.Notification) {
                    console.log('🔐 Overriding Notification API...');
                    
                    const originalRequestPermission = window.Notification.requestPermission;
                    
                    window.Notification.requestPermission = function(callback) {
                        console.log('🔐 Notification permission requested');
                        
                        if (zooboxPermissions.notifications === 'granted') {
                            console.log('✅ Notification permission already granted');
                            if (callback) {
                                callback('granted');
                            }
                            return Promise.resolve('granted');
                        } else {
                            console.log('❌ Notification permission not granted - requesting permission');
                            if (window.ZooboxBridge && window.ZooboxBridge.requestPermission) {
                                window.ZooboxBridge.requestPermission('notifications');
                            }
                            if (callback) {
                                callback('denied');
                            }
                            return Promise.resolve('denied');
                        }
                    };
                    
                    console.log('✅ Notification API overridden successfully');
                }
                
                // Override getUserMedia API (for camera/microphone)
                if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                    console.log('🔐 Overriding getUserMedia API...');
                    
                    const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
                    
                    navigator.mediaDevices.getUserMedia = function(constraints) {
                        console.log('🔐 getUserMedia called with constraints:', constraints);
                        
                        // Check what permissions are needed
                        const needsCamera = constraints.video;
                        const needsMicrophone = constraints.audio;
                        
                        let canProceed = true;
                        let missingPermissions = [];
                        
                        if (needsCamera && zooboxPermissions.camera !== 'granted') {
                            canProceed = false;
                            missingPermissions.push('camera');
                        }
                        
                        if (needsMicrophone && zooboxPermissions.microphone !== 'granted') {
                            canProceed = false;
                            missingPermissions.push('microphone');
                        }
                        
                        if (canProceed) {
                            console.log('✅ All required permissions granted - proceeding with getUserMedia');
                            return originalGetUserMedia.call(navigator.mediaDevices, constraints);
                        } else {
                            console.log('❌ Missing permissions:', missingPermissions);
                            
                            // Request missing permissions
                            missingPermissions.forEach(permission => {
                                if (window.ZooboxBridge && window.ZooboxBridge.requestPermission) {
                                    window.ZooboxBridge.requestPermission(permission);
                                }
                            });
                            
                            // Return rejected promise
                            return Promise.reject(new DOMException(
                                'Permission denied - please grant ' + missingPermissions.join(' and ') + ' permission in the app',
                                'NotAllowedError'
                            ));
                        }
                    };
                    
                    console.log('✅ getUserMedia API overridden successfully');
                }
                
                // Listen for permission updates from native app
                window.addEventListener('zooboxPermissionsUpdate', function(event) {
                    console.log('🔐 Permissions updated from native app:', event.detail);
                    zooboxPermissions = event.detail;
                    
                    // Re-evaluate any pending permission requests
                    console.log('🔄 Permission status updated - re-evaluating pending requests');
                });
                
                // Override permission query API if available
                if (navigator.permissions && navigator.permissions.query) {
                    console.log('🔐 Overriding permissions.query API...');
                    
                    const originalQuery = navigator.permissions.query;
                    
                    navigator.permissions.query = function(permissionDescriptor) {
                        console.log('🔐 Permission query:', permissionDescriptor);
                        
                        const permissionName = permissionDescriptor.name;
                        let permissionStatus = 'denied';
                        
                        switch (permissionName) {
                            case 'geolocation':
                                permissionStatus = zooboxPermissions.location === 'granted' ? 'granted' : 'denied';
                                break;
                            case 'notifications':
                                permissionStatus = zooboxPermissions.notifications === 'granted' ? 'granted' : 'denied';
                                break;
                            case 'camera':
                                permissionStatus = zooboxPermissions.camera === 'granted' ? 'granted' : 'denied';
                                break;
                            case 'microphone':
                                permissionStatus = zooboxPermissions.microphone === 'granted' ? 'granted' : 'denied';
                                break;
                            default:
                                // Use original API for unknown permissions
                                return originalQuery.call(navigator.permissions, permissionDescriptor);
                        }
                        
                        console.log('🔐 Permission status for', permissionName, ':', permissionStatus);
                        
                        // Return a mock PermissionStatus object
                        return Promise.resolve({
                            state: permissionStatus,
                            onchange: null
                        });
                    };
                    
                    console.log('✅ permissions.query API overridden successfully');
                }
                
                // Prevent any existing permission dialogs from showing
                const preventPermissionDialogs = function() {
                    // Override any existing permission request methods
                    if (window.confirm) {
                        const originalConfirm = window.confirm;
                        window.confirm = function(message) {
                            if (message && (message.includes('location') || message.includes('camera') || message.includes('microphone'))) {
                                console.log('🔐 Blocking permission dialog:', message);
                                return false;
                            }
                            return originalConfirm.call(window, message);
                        };
                    }
                    
                    // Override alert for permission-related messages
                    if (window.alert) {
                        const originalAlert = window.alert;
                        window.alert = function(message) {
                            if (message && (message.includes('location') || message.includes('camera') || message.includes('microphone'))) {
                                console.log('🔐 Blocking permission alert:', message);
                                return;
                            }
                            return originalAlert.call(window, message);
                        };
                    }
                };
                
                // Run prevention immediately
                preventPermissionDialogs();
                
                // Also run after DOM is ready
                if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', preventPermissionDialogs);
                }
                
                console.log('🔐 Zoobox Permission Override System Initialized Successfully');
                console.log('🔐 Current permissions:', zooboxPermissions);
                
            })();
        """
        
        webView.evaluateJavaScript(permissionOverrideScript) { _, error in
            if let error = error {
                print("🔐 Error injecting permission override script: \(error)")
            } else {
                print("🔐 Permission override script injected successfully")
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
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
                 runOpenPanelWith parameters: WKOpenPanelParameters,
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
        // Check camera/microphone permissions
        switch type {
        case .camera:
            if permissionManager.isPermissionGranted(for: .camera) {
                decisionHandler(.grant)
            } else {
                permissionManager.requestPermissionWithExplanation(for: .camera, from: self)
                decisionHandler(.deny)
            }
        case .microphone:
            if permissionManager.isPermissionGranted(for: .microphone) {
                decisionHandler(.grant)
            } else {
                permissionManager.requestPermissionWithExplanation(for: .microphone, from: self)
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
        
        if permissionManager.isPermissionGranted(for: .location) {
            print("✅ Location permission already granted - allowing WebView access")
            decisionHandler(.grant)
        } else {
            print("❌ Location permission not granted - showing permission request")
            permissionManager.requestPermissionWithExplanation(for: .location, from: self)
            decisionHandler(.deny)
        }
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
    
    // MARK: - Cookie Management Methods (Optional)
    private func saveCookies() {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                print("Cookie: \(cookie.name) = \(cookie.value)")
            }
        }
    }
    private func loadSavedCookies() {
        // Optional: implement cookie loading here
    }
    
    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "hapticFeedback")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "locationRequest")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "startRealTimeLocation")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "stopRealTimeLocation")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "injectLocation")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "nativeMessage")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "requestPermission")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "getPermissionStatus")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "connectionRestored")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "connectionLost")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "retryConnection")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "checkSettings")
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "enableOfflineMode")
    }
    
    // MARK: - PermissionManagerDelegate
    
    func permissionManager(_ manager: PermissionManager, didUpdatePermissions permissions: [PermissionType: PermissionStatus]) {
        // Inject updated permissions to WebView
        permissionManager.injectPermissionStatusToWebView(webView)
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



