import UIKit
import WebKit
import AVFoundation
import CoreLocation

class MainViewController: UIViewController, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate, ConnectivityManagerDelegate {
    private var webView: NoZoomWKWebView!

    private var refreshControl: UIRefreshControl!
    private var isRefreshing = false
    private var currentNavigation: WKNavigation?
    private var retryCount = 0
    private var lastError: Error?
    private var loadingTimer: Timer?
    private var isWebViewLoaded = false
    private var pendingJSResponses: [String] = []
    private var isWebViewFullyReady = false
    private var webViewReadyTimer: Timer?
    private var loadingIndicatorTimeout: Timer?

    
    // Device-specific timeout and retry values
    private var maxRetryCount: Int {
        return UIDevice.current.maxRetryCount
    }
    
    private var loadingTimeout: TimeInterval {
        return UIDevice.current.webViewTimeout
    }
    
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🔄 [MainViewController] viewDidLoad called")
        print("⏰ [MainViewController] viewDidLoad time: \(Date())")
        
        // Set up white background for top safe area
        setupTopSafeAreaBackground()
        
        setupRefreshControl()
        setupWebView()
        setupConnectivityManager()
        setupNotificationObservers()
        
        // Start location update service (only if permission already granted)
        setupLocationUpdateService()
        
        // Remove bottom safe area completely
        additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: -view.safeAreaInsets.bottom, right: 0)
        
        print("✅ [MainViewController] viewDidLoad completed")
    }
    
    private func setupTopSafeAreaBackground() {
        // Create a white background view for the top safe area
        let topSafeAreaView = UIView()
        topSafeAreaView.backgroundColor = UIColor.white
        topSafeAreaView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(topSafeAreaView)
        
        NSLayoutConstraint.activate([
            topSafeAreaView.topAnchor.constraint(equalTo: view.topAnchor),
            topSafeAreaView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topSafeAreaView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topSafeAreaView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
    }
    

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("🔄 [MainViewController] viewWillAppear called")
        print("⏰ [MainViewController] viewWillAppear time: \(Date())")
        ConnectivityManager.shared.startMonitoring()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        print("🔄 [MainViewController] viewDidAppear called")
        print("⏰ [MainViewController] viewDidAppear time: \(Date())")
        
        // Keep loading indicator visible until webview starts loading
        print("📱 [MainViewController] Keeping loading indicator visible until webview starts")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        ConnectivityManager.shared.stopMonitoring()
    }
    

    

    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        print("📱 [MainViewController] Orientation change detected")
        print("📱 [MainViewController] New size: \(size)")
        print("📱 [MainViewController] Device: \(UIDevice.current.deviceFamily)")
        print("📱 [MainViewController] Orientation: \(UIDevice.current.orientationString)")
        

    }
    
    deinit {
        // Clean up observers and timers
        NotificationCenter.default.removeObserver(self)
        loadingTimer?.invalidate()
        webViewReadyTimer?.invalidate()
        loadingIndicatorTimeout?.invalidate()
        
        // Clean up pending responses
        pendingJSResponses.removeAll()
        
        // Remove message handlers safely
        if let webView = webView {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "hapticFeedback")
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "permissionBridge")
        }
        
        print("🔄 [MainViewController] Deinitialized")
    }
    
    private func setupRefreshControl() {
        // Create refresh control with device-specific styling
        refreshControl = UIRefreshControl()
        
        // Device-specific refresh control styling
        let fontSize: CGFloat = UIDevice.current.isIPad ? 16 : 14
        let fontWeight: UIFont.Weight = UIDevice.current.isIPad ? .semibold : .medium
        
        refreshControl.attributedTitle = NSAttributedString(
            string: "Pull to refresh",
            attributes: [
                .foregroundColor: UIColor.systemBlue,
                .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
            ]
        )
        
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        // Note: refreshControl will be added to webView.scrollView after WebView is created
    }
    
    private func setupWebView() {
        print("🔄 [MainViewController] Setting up WebView")
        
        do {
            // Create WebView configuration with error handling
            let configuration = WKWebViewConfiguration()
            
            // Add safety check for configuration
            print("📱 [WebView] Configuration created successfully")
        
        // Device-specific WebView configuration
        if UIDevice.current.isIPad {
            print("📱 [WebView] Applying iPad-specific configuration")
            
            // iPad-specific process pool configuration
            configuration.processPool = WKProcessPool()
            print("📱 [WebView] iPad process pool configured")
            
            // iPad-specific user content controller
            let userContentController = WKUserContentController()
            print("📱 [WebView] iPad user content controller created")
            
            // Add haptic feedback bridge for iPad
            userContentController.add(self, name: "hapticFeedback")
            print("📱 [WebView] iPad haptic feedback bridge added")
            
            // Set user content controller
            configuration.userContentController = userContentController
            print("📱 [WebView] iPad user content controller set")
            
            // Prevent permission dialogs by setting media types that don't require user action
            configuration.mediaTypesRequiringUserActionForPlayback = []
            print("📱 [WebView] iPad media types requiring user action set to empty")
            
            // Additional settings to prevent permission dialogs
            configuration.allowsInlineMediaPlayback = true
            configuration.allowsAirPlayForMediaPlayback = true
            print("📱 [WebView] iPad inline media and airplay settings configured")
            
            // Inject iPad-specific viewport meta tag and disable zoom
            print("📱 [WebView] Creating iPad viewport script")
            let viewportScript = WKUserScript(
                source: """
                var viewport = document.querySelector('meta[name="viewport"]');
                if (!viewport) {
                    viewport = document.createElement('meta');
                    viewport.name = 'viewport';
                    document.head.appendChild(viewport);
                }
                viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, viewport-fit=cover';
                
                // Disable zoom gestures
                document.addEventListener('gesturestart', function(e) {
                    e.preventDefault();
                }, { passive: false });
                
                document.addEventListener('gesturechange', function(e) {
                    e.preventDefault();
                }, { passive: false });
                
                document.addEventListener('gestureend', function(e) {
                    e.preventDefault();
                }, { passive: false });
                
                // Disable double-tap zoom
                let lastTouchEnd = 0;
                document.addEventListener('touchend', function(event) {
                    const now = (new Date()).getTime();
                    if (now - lastTouchEnd <= 300) {
                        event.preventDefault();
                    }
                    lastTouchEnd = now;
                }, { passive: false });
                
                // Disable long-press context menu on all elements
                document.addEventListener('contextmenu', function(e) {
                    e.preventDefault();
                }, { passive: false });
                
                // Disable long-press on links and buttons
                document.addEventListener('touchstart', function(e) {
                    // Prevent long-press on interactive elements
                    const target = e.target;
                    if (target.tagName === 'A' || target.tagName === 'BUTTON' || target.getAttribute('role') === 'button' || target.onclick) {
                        // Set a timer to prevent long-press
                        const timer = setTimeout(function() {
                            // This will prevent the long-press menu
                        }, 500);
                        
                        // Clear timer on touch end
                        const clearTimer = function() {
                            clearTimeout(timer);
                            document.removeEventListener('touchend', clearTimer);
                            document.removeEventListener('touchcancel', clearTimer);
                        };
                        
                        document.addEventListener('touchend', clearTimer, { once: true });
                        document.addEventListener('touchcancel', clearTimer, { once: true });
                    }
                }, { passive: true });
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(viewportScript)
            print("📱 [WebView] iPad viewport script added")
            
            // Inject iPad-specific CSS for better layout
            print("📱 [WebView] Creating iPad CSS script")
            let cssScript = WKUserScript(
                source: """
                var style = document.createElement('style');
                style.textContent = `
                    html, body {
                        touch-action: manipulation;
                        -ms-touch-action: manipulation;
                    }
                    body { 
                        -webkit-text-size-adjust: 100%; 
                        -webkit-tap-highlight-color: transparent;
                        margin: 0;
                        padding: 0;
                        overflow-x: hidden;
                    }
                    * { 
                        -webkit-touch-callout: none;
                        -webkit-user-select: none;
                        user-select: none;
                    }
                    input, textarea { 
                        -webkit-user-select: text;
                        user-select: text;
                    }
                `;
                document.head.appendChild(style);
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(cssScript)
            print("📱 [WebView] iPad CSS script added")
            
            // Inject iPad-specific haptic feedback script
            print("📱 [WebView] Creating iPad haptic feedback script")
            let hapticScript = WKUserScript(
                source: """
                // Haptic feedback for interactive elements - only on actual taps/clicks
                function addHapticFeedback() {
                    // Select all interactive elements
                    const interactiveElements = document.querySelectorAll('a, button, input, select, textarea, [role="button"], [tabindex], [onclick], [onmousedown], [ontouchstart]');
                    
                    interactiveElements.forEach(function(element) {
                        let touchStartTime = 0;
                        let touchStartY = 0;
                        let touchStartX = 0;
                        let hasMoved = false;
                        
                        // Track touch start
                        element.addEventListener('touchstart', function(e) {
                            touchStartTime = Date.now();
                            touchStartY = e.touches[0].clientY;
                            touchStartX = e.touches[0].clientX;
                            hasMoved = false;
                        }, { passive: true });
                        
                        // Track touch move to detect scrolling
                        element.addEventListener('touchmove', function(e) {
                            const currentY = e.touches[0].clientY;
                            const currentX = e.touches[0].clientX;
                            const deltaY = Math.abs(currentY - touchStartY);
                            const deltaX = Math.abs(currentX - touchStartX);
                            
                            // If moved more than 10px, consider it a scroll
                            if (deltaY > 10 || deltaX > 10) {
                                hasMoved = true;
                            }
                        }, { passive: true });
                        
                        // Only trigger haptic feedback on actual taps (not scrolls)
                        element.addEventListener('touchend', function(e) {
                            const touchEndTime = Date.now();
                            const touchDuration = touchEndTime - touchStartTime;
                            
                            // Only trigger if:
                            // 1. Touch duration is less than 300ms (quick tap)
                            // 2. No significant movement (not a scroll)
                            // 3. Touch ended on the same element
                            if (touchDuration < 300 && !hasMoved && e.target === element) {
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hapticFeedback) {
                                    window.webkit.messageHandlers.hapticFeedback.postMessage('light');
                                }
                            }
                        }, { passive: true });
                        
                        // For mouse events (iPad with mouse), use click instead of mousedown
                        element.addEventListener('click', function(e) {
                            // Only trigger if it's a real click (not programmatic)
                            if (e.isTrusted) {
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hapticFeedback) {
                                    window.webkit.messageHandlers.hapticFeedback.postMessage('light');
                                }
                            }
                        }, { passive: true });
                    });
                    
                    // Also handle dynamically added elements
                    const observer = new MutationObserver(function(mutations) {
                        mutations.forEach(function(mutation) {
                            mutation.addedNodes.forEach(function(node) {
                                if (node.nodeType === 1) { // Element node
                                    const newInteractiveElements = node.querySelectorAll ? node.querySelectorAll('a, button, input, select, textarea, [role="button"], [tabindex], [onclick], [onmousedown], [ontouchstart]') : [];
                                    newInteractiveElements.forEach(function(element) {
                                        let touchStartTime = 0;
                                        let touchStartY = 0;
                                        let touchStartX = 0;
                                        let hasMoved = false;
                                        
                                        // Track touch start
                                        element.addEventListener('touchstart', function(e) {
                                            touchStartTime = Date.now();
                                            touchStartY = e.touches[0].clientY;
                                            touchStartX = e.touches[0].clientX;
                                            hasMoved = false;
                                        }, { passive: true });
                                        
                                        // Track touch move to detect scrolling
                                        element.addEventListener('touchmove', function(e) {
                                            const currentY = e.touches[0].clientY;
                                            const currentX = e.touches[0].clientX;
                                            const deltaY = Math.abs(currentY - touchStartY);
                                            const deltaX = Math.abs(currentX - touchStartX);
                                            
                                            // If moved more than 10px, consider it a scroll
                                            if (deltaY > 10 || deltaX > 10) {
                                                hasMoved = true;
                                            }
                                        }, { passive: true });
                                        
                                        // Only trigger haptic feedback on actual taps (not scrolls)
                                        element.addEventListener('touchend', function(e) {
                                            const touchEndTime = Date.now();
                                            const touchDuration = touchEndTime - touchStartTime;
                                            
                                            // Only trigger if:
                                            // 1. Touch duration is less than 300ms (quick tap)
                                            // 2. No significant movement (not a scroll)
                                            // 3. Touch ended on the same element
                                            if (touchDuration < 300 && !hasMoved && e.target === element) {
                                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hapticFeedback) {
                                                    window.webkit.messageHandlers.hapticFeedback.postMessage('light');
                                                }
                                            }
                                        }, { passive: true });
                                        
                                        // For mouse events (iPad with mouse), use click instead of mousedown
                                        element.addEventListener('click', function(e) {
                                            // Only trigger if it's a real click (not programmatic)
                                            if (e.isTrusted) {
                                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hapticFeedback) {
                                                    window.webkit.messageHandlers.hapticFeedback.postMessage('light');
                                                }
                                            }
                                        }, { passive: true });
                                    });
                                }
                            });
                        });
                    });
                    
                    observer.observe(document.body, { childList: true, subtree: true });
                }
                
                // Initialize haptic feedback when DOM is ready
                if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', addHapticFeedback);
                } else {
                    addHapticFeedback();
                }
                
                // Also run on page load for single-page applications
                window.addEventListener('load', addHapticFeedback);
                """,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(hapticScript)
            print("📱 [WebView] iPad haptic feedback script added")
            
            configuration.userContentController = userContentController
            print("📱 [WebView] iPad user content controller assigned")
            
            // iPad-specific application name
            configuration.applicationNameForUserAgent = "Zoobox iPad"
            print("📱 [WebView] iPad user agent set")
            
        } else {
            // iPhone-specific configuration
            print("📱 [WebView] Applying iPhone-specific configuration")
            
            // iPhone-specific user content controller
            let userContentController = WKUserContentController()
            print("📱 [WebView] iPhone user content controller created")
            
            // Add haptic feedback bridge for iPhone
            userContentController.add(self, name: "hapticFeedback")
            print("📱 [WebView] iPhone haptic feedback bridge added")
            
            // Set user content controller
            configuration.userContentController = userContentController
            print("📱 [WebView] iPhone user content controller set")
            
            // Prevent permission dialogs by setting media types that don't require user action
            configuration.mediaTypesRequiringUserActionForPlayback = []
            print("📱 [WebView] iPhone media types requiring user action set to empty")
            
            // Additional settings to prevent permission dialogs
            configuration.allowsInlineMediaPlayback = true
            print("📱 [WebView] iPhone inline media settings configured")
            
            // Inject iPhone-specific viewport meta tag and disable zoom
            print("📱 [WebView] Creating iPhone viewport script")
            let viewportScript = WKUserScript(
                source: """
                var viewport = document.querySelector('meta[name="viewport"]');
                if (!viewport) {
                    viewport = document.createElement('meta');
                    viewport.name = 'viewport';
                    document.head.appendChild(viewport);
                }
                viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no, viewport-fit=cover';
                
                // Disable zoom gestures
                document.addEventListener('gesturestart', function(e) {
                    e.preventDefault();
                }, { passive: false });
                
                document.addEventListener('gesturechange', function(e) {
                    e.preventDefault();
                }, { passive: false });
                
                document.addEventListener('gestureend', function(e) {
                    e.preventDefault();
                }, { passive: false });
                
                // Disable double-tap zoom
                let lastTouchEnd = 0;
                document.addEventListener('touchend', function(event) {
                    const now = (new Date()).getTime();
                    if (now - lastTouchEnd <= 300) {
                        event.preventDefault();
                    }
                    lastTouchEnd = now;
                }, { passive: false });
                
                // Disable long-press context menu on all elements
                document.addEventListener('contextmenu', function(e) {
                    e.preventDefault();
                }, { passive: false });
                
                // Disable long-press on links and buttons
                document.addEventListener('touchstart', function(e) {
                    // Prevent long-press on interactive elements
                    const target = e.target;
                    if (target.tagName === 'A' || target.tagName === 'BUTTON' || target.getAttribute('role') === 'button' || target.onclick) {
                        // Set a timer to prevent long-press
                        const timer = setTimeout(function() {
                            // This will prevent the long-press menu
                        }, 500);
                        
                        // Clear timer on touch end
                        const clearTimer = function() {
                            clearTimeout(timer);
                            document.removeEventListener('touchend', clearTimer);
                            document.removeEventListener('touchcancel', clearTimer);
                        };
                        
                        document.addEventListener('touchend', clearTimer, { once: true });
                        document.addEventListener('touchcancel', clearTimer, { once: true });
                    }
                }, { passive: true });
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(viewportScript)
            print("📱 [WebView] iPhone viewport script added")
            
            // Inject iPhone-specific CSS
            print("📱 [WebView] Creating iPhone CSS script")
            let cssScript = WKUserScript(
                source: """
                var style = document.createElement('style');
                style.textContent = `
                    html, body {
                        touch-action: manipulation;
                        -ms-touch-action: manipulation;
                    }
                    body { 
                        -webkit-text-size-adjust: 100%; 
                        -webkit-tap-highlight-color: transparent;
                        margin: 0;
                        padding: 0;
                        overflow-x: hidden;
                    }
                    * { 
                        -webkit-touch-callout: none;
                        -webkit-user-select: none;
                        user-select: none;
                    }
                    input, textarea { 
                        -webkit-user-select: text;
                        user-select: text;
                    }
                `;
                document.head.appendChild(style);
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(cssScript)
            print("📱 [WebView] iPhone CSS script added")
            
            // Inject iPhone-specific haptic feedback script
            print("📱 [WebView] Creating iPhone haptic feedback script")
            let hapticScript = WKUserScript(
                source: """
                // Haptic feedback for interactive elements - only on actual taps/clicks
                function addHapticFeedback() {
                    // Select all interactive elements
                    const interactiveElements = document.querySelectorAll('a, button, input, select, textarea, [role="button"], [tabindex], [onclick], [onmousedown], [ontouchstart]');
                    
                    interactiveElements.forEach(function(element) {
                        let touchStartTime = 0;
                        let touchStartY = 0;
                        let touchStartX = 0;
                        let hasMoved = false;
                        
                        // Track touch start
                        element.addEventListener('touchstart', function(e) {
                            touchStartTime = Date.now();
                            touchStartY = e.touches[0].clientY;
                            touchStartX = e.touches[0].clientX;
                            hasMoved = false;
                        }, { passive: true });
                        
                        // Track touch move to detect scrolling
                        element.addEventListener('touchmove', function(e) {
                            const currentY = e.touches[0].clientY;
                            const currentX = e.touches[0].clientX;
                            const deltaY = Math.abs(currentY - touchStartY);
                            const deltaX = Math.abs(currentX - touchStartX);
                            
                            // If moved more than 10px, consider it a scroll
                            if (deltaY > 10 || deltaX > 10) {
                                hasMoved = true;
                            }
                        }, { passive: true });
                        
                        // Only trigger haptic feedback on actual taps (not scrolls)
                        element.addEventListener('touchend', function(e) {
                            const touchEndTime = Date.now();
                            const touchDuration = touchEndTime - touchStartTime;
                            
                            // Only trigger if:
                            // 1. Touch duration is less than 300ms (quick tap)
                            // 2. No significant movement (not a scroll)
                            // 3. Touch ended on the same element
                            if (touchDuration < 300 && !hasMoved && e.target === element) {
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hapticFeedback) {
                                    window.webkit.messageHandlers.hapticFeedback.postMessage('light');
                                }
                            }
                        }, { passive: true });
                        
                        // For mouse events (iPhone with mouse), use click instead of mousedown
                        element.addEventListener('click', function(e) {
                            // Only trigger if it's a real click (not programmatic)
                            if (e.isTrusted) {
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hapticFeedback) {
                                    window.webkit.messageHandlers.hapticFeedback.postMessage('light');
                                }
                            }
                        }, { passive: true });
                    });
                    
                    // Also handle dynamically added elements
                    const observer = new MutationObserver(function(mutations) {
                        mutations.forEach(function(mutation) {
                            mutation.addedNodes.forEach(function(node) {
                                if (node.nodeType === 1) { // Element node
                                    const newInteractiveElements = node.querySelectorAll ? node.querySelectorAll('a, button, input, select, textarea, [role="button"], [tabindex], [onclick], [onmousedown], [ontouchstart]') : [];
                                    newInteractiveElements.forEach(function(element) {
                                        let touchStartTime = 0;
                                        let touchStartY = 0;
                                        let touchStartX = 0;
                                        let hasMoved = false;
                                        
                                        // Track touch start
                                        element.addEventListener('touchstart', function(e) {
                                            touchStartTime = Date.now();
                                            touchStartY = e.touches[0].clientY;
                                            touchStartX = e.touches[0].clientX;
                                            hasMoved = false;
                                        }, { passive: true });
                                        
                                        // Track touch move to detect scrolling
                                        element.addEventListener('touchmove', function(e) {
                                            const currentY = e.touches[0].clientY;
                                            const currentX = e.touches[0].clientX;
                                            const deltaX = Math.abs(currentX - touchStartX);
                                            const deltaY = Math.abs(currentY - touchStartY);
                                            
                                            // If moved more than 10px, consider it a scroll
                                            if (deltaY > 10 || deltaX > 10) {
                                                hasMoved = true;
                                            }
                                        }, { passive: true });
                                        
                                        // Only trigger haptic feedback on actual taps (not scrolls)
                                        element.addEventListener('touchend', function(e) {
                                            const touchEndTime = Date.now();
                                            const touchDuration = touchEndTime - touchStartTime;
                                            
                                            // Only trigger if:
                                            // 1. Touch duration is less than 300ms (quick tap)
                                            // 2. No significant movement (not a scroll)
                                            // 3. Touch ended on the same element
                                            if (touchDuration < 300 && !hasMoved && e.target === element) {
                                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hapticFeedback) {
                                                    window.webkit.messageHandlers.hapticFeedback.postMessage('light');
                                                }
                                            }
                                        }, { passive: true });
                                        
                                        // For mouse events (iPhone with mouse), use click instead of mousedown
                                        element.addEventListener('click', function(e) {
                                            // Only trigger if it's a real click (not programmatic)
                                            if (e.isTrusted) {
                                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hapticFeedback) {
                                                    window.webkit.messageHandlers.hapticFeedback.postMessage('light');
                                                }
                                            }
                                        }, { passive: true });
                                    });
                                }
                            });
                        });
                    });
                    
                    observer.observe(document.body, { childList: true, subtree: true });
                }
                
                // Initialize haptic feedback when DOM is ready
                if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', addHapticFeedback);
                } else {
                    addHapticFeedback();
                }
                
                // Also run on page load for single-page applications
                window.addEventListener('load', addHapticFeedback);
                """,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(hapticScript)
            print("📱 [WebView] iPhone haptic feedback script added")
            
            // iPhone-specific application name
            configuration.applicationNameForUserAgent = "Zoobox iPhone"
            print("📱 [WebView] iPhone user agent set")
        }
        
        // Common WebView configuration for both devices
        print("📱 [WebView] Setting up common configuration")
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.suppressesIncrementalRendering = true
        print("📱 [WebView] Common configuration completed")
        
        // Device-specific additional configurations
        if UIDevice.current.isIPad {
            // iPad-specific additional settings
            print("📱 [WebView] Setting up iPad-specific media settings")
            configuration.allowsAirPlayForMediaPlayback = true
            configuration.allowsPictureInPictureMediaPlayback = true
            print("📱 [WebView] iPad media settings completed")
        }
        
        // Create WebView with device-specific configuration
        print("📱 [WebView] Creating WKWebView with configuration")
        webView = NoZoomWKWebView(frame: view.bounds, configuration: configuration)
        webView.allowsLinkPreview = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        
        // Additional native zoom prevention
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.zoomScale = 1.0
        webView.scrollView.bouncesZoom = false
        print("📱 [WebView] WKWebView created successfully")
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.uiDelegate = self
        
        // Disable geolocation permission prompts completely
        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView.configuration.preferences.javaScriptEnabled = true
        
        // Additional settings to prevent permission dialogs
        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Set custom user agent to indicate this is a native app
        webView.customUserAgent = "Zoobox/2.0 (iOS; Native App)"
        
        // Device-specific WebView settings
        if UIDevice.current.isIPad {
            // iPad-specific settings
            webView.scrollView.contentInsetAdjustmentBehavior = .never
            webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            webView.scrollView.showsVerticalScrollIndicator = false
            webView.scrollView.showsHorizontalScrollIndicator = false
        } else {
            // iPhone-specific settings
            webView.scrollView.contentInsetAdjustmentBehavior = .never
            webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            webView.scrollView.showsVerticalScrollIndicator = false
            webView.scrollView.showsHorizontalScrollIndicator = false
        }
        
        // Enable webview scrolling for content
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set up WebView constraints to fill the view
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        

        
        // Add refresh control to WebView's scroll view
        webView.scrollView.refreshControl = refreshControl
        
        // Setup permission bridge BEFORE loading URL to prevent race conditions
        setupPermissionBridge()
        
        // Setup custom URL scheme handler for geolocation
        setupGeolocationURLSchemeHandler()
        
        // Load default URL with device-specific timeout
        print("🔄 [MainViewController] About to load initial URL")
        print("📱 [WebView] Device: \(UIDevice.current.deviceFamily)")
        print("📱 [WebView] Timeout: \(UIDevice.current.webViewTimeout) seconds")
        print("📱 [WebView] Max retries: \(UIDevice.current.maxRetryCount)")
        
        if let url = URL(string: "https://mikmik.site") {
            print("📱 [WebView] Loading URL: \(url)")
            loadURL(url)
        } else {
            print("❌ [WebView] Failed to create URL")
        }
        print("✅ [MainViewController] WebView setup completed")
        
        } catch {
            print("❌ [WebView] Error during WebView setup: \(error)")
            print("❌ [WebView] Error details: \(error.localizedDescription)")
            
            // Fallback to basic WebView configuration
            print("📱 [WebView] Attempting fallback configuration")
            let fallbackConfiguration = WKWebViewConfiguration()
            webView = NoZoomWKWebView(frame: view.bounds, configuration: fallbackConfiguration)
            webView.allowsLinkPreview = false
            webView.scrollView.pinchGestureRecognizer?.isEnabled = false
            
            // Additional native zoom prevention
            webView.scrollView.maximumZoomScale = 1.0
            webView.scrollView.minimumZoomScale = 1.0
            webView.scrollView.zoomScale = 1.0
            webView.scrollView.bouncesZoom = false
            webView.navigationDelegate = self
            
            if let url = URL(string: "https://mikmik.site") {
                loadURL(url)
            }
        }
    }
    

    
    @objc private func handleRefresh() {
        isRefreshing = true
        
        // Check connectivity first
        let isConnected = ConnectivityManager.shared.currentConnectivityStatus == .connected
        
        if !isConnected {
            // Device-specific refresh control styling
            let fontSize: CGFloat = UIDevice.current.isIPad ? 16 : 14
            let fontWeight: UIFont.Weight = UIDevice.current.isIPad ? .semibold : .medium
            
            // Show no internet connection message
            refreshControl.attributedTitle = NSAttributedString(
                string: "No internet connection",
                attributes: [
                    .foregroundColor: UIColor.systemOrange,
                    .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
                ]
            )
            
            // End refreshing immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshControl.endRefreshing()
                self.isRefreshing = false
                
                // Reset to default state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.updateRefreshControlForConnectivity()
                }
            }
            return
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Update refresh control title with device-specific styling
        let fontSize: CGFloat = UIDevice.current.isIPad ? 16 : 14
        let fontWeight: UIFont.Weight = UIDevice.current.isIPad ? .semibold : .medium
        
        refreshControl.attributedTitle = NSAttributedString(
            string: "Refreshing...",
            attributes: [
                .foregroundColor: UIColor.systemBlue,
                .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
            ]
        )
        
        // Reload the current page
        if let currentURL = webView.url {
            loadURL(currentURL)
        } else if let url = URL(string: "https://mikmik.site") {
            loadURL(url)
        }
    }
    
    private func showRefreshSuccess() {
        // Haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        // Device-specific refresh control styling
        let fontSize: CGFloat = UIDevice.current.isIPad ? 16 : 14
        let fontWeight: UIFont.Weight = UIDevice.current.isIPad ? .semibold : .medium
        
        // Update refresh control with success state
        refreshControl.attributedTitle = NSAttributedString(
            string: "Refreshed successfully",
            attributes: [
                .foregroundColor: UIColor.systemGreen,
                .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
            ]
        )
        
        // End refreshing after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.refreshControl.endRefreshing()
            self.isRefreshing = false
            
            // Reset to default state after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.refreshControl.attributedTitle = NSAttributedString(
                    string: "Pull to refresh",
                    attributes: [
                        .foregroundColor: UIColor.systemBlue,
                        .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
                    ]
                )
            }
        }
    }
    
    private func showRefreshError() {
        // Haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
        
        // Device-specific refresh control styling
        let fontSize: CGFloat = UIDevice.current.isIPad ? 16 : 14
        let fontWeight: UIFont.Weight = UIDevice.current.isIPad ? .semibold : .medium
        
        // Update refresh control with error state
        refreshControl.attributedTitle = NSAttributedString(
            string: "Refresh failed",
            attributes: [
                .foregroundColor: UIColor.systemRed,
                .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
            ]
        )
        
        // End refreshing after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.refreshControl.endRefreshing()
            self.isRefreshing = false
            
            // Reset to default state after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.refreshControl.attributedTitle = NSAttributedString(
                    string: "Pull to refresh",
                    attributes: [
                        .foregroundColor: UIColor.systemBlue,
                        .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
                    ]
                )
            }
        }
    }
    
    private func setupConnectivityManager() {
        ConnectivityManager.shared.delegate = self
    }
    
    private func setupLocationUpdateService() {
        let locationService = LocationUpdateService.shared
        print("📍 [MainViewController] Setting up location update service")
        
        // Only start location services if permission is already granted
        // This prevents triggering permission requests after onboarding is complete
        let authStatus = CLLocationManager.authorizationStatus()
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            locationService.startLocationServices()
            print("📍 [MainViewController] Location services started - permission already granted")
        } else {
            print("📍 [MainViewController] Location services not started - permission not granted")
        }
    }
    
    private func setupNotificationObservers() {
        // Listen for FCM deep link notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeepLinkNotification),
            name: NSNotification.Name("OpenDeepLinkURL"),
            object: nil
        )
    }
    
    private func setupPermissionBridge() {
        // Add permission bridge message handler
        webView.configuration.userContentController.add(self, name: "permissionBridge")
        
        // Inject permission bridge JavaScript
        let permissionBridgeScript = WKUserScript(
            source: """
            // Permission Bridge for Native App Integration
            window.ZooboxPermissionBridge = {
                // Check if permission is granted natively
                checkPermission: function(permissionType) {
                    return new Promise((resolve) => {
                        window.webkit.messageHandlers.permissionBridge.postMessage({
                            action: 'checkPermission',
                            permissionType: permissionType
                        });
                        
                        // Store the resolve function to be called by native code
                        if (!window._permissionCallbacks) {
                            window._permissionCallbacks = {};
                        }
                        window._permissionCallbacks[permissionType] = resolve;
                    });
                },
                
                // Check camera permission
                checkCameraPermission: function() {
                    return this.checkPermission('camera');
                },
                
                // Check location permission
                checkLocationPermission: function() {
                    return this.checkPermission('location');
                },
                
                // Check microphone permission
                checkMicrophonePermission: function() {
                    return this.checkPermission('microphone');
                },
                
                // Get all permission statuses at once
                getAllPermissions: function() {
                    return new Promise((resolve) => {
                        window.webkit.messageHandlers.permissionBridge.postMessage({
                            action: 'getAllPermissions'
                        });
                        
                        if (!window._permissionCallbacks) {
                            window._permissionCallbacks = {};
                        }
                        window._permissionCallbacks['all'] = resolve;
                    });
                },
                
                // Helper function to resolve permission callbacks (called by native code)
                _resolvePermission: function(permissionType, isGranted) {
                    if (window._permissionCallbacks && window._permissionCallbacks[permissionType]) {
                        window._permissionCallbacks[permissionType](isGranted);
                        delete window._permissionCallbacks[permissionType];
                    }
                },
                
                // Helper function to resolve all permissions callback (called by native code)
                _resolveAllPermissions: function(permissions) {
                    if (window._permissionCallbacks && window._permissionCallbacks['all']) {
                        window._permissionCallbacks['all'](permissions);
                        delete window._permissionCallbacks['all'];
                    }
                }
            };
            
            // Make it globally available
            window.zooboxPermissions = window.ZooboxPermissionBridge;
            
            // Completely override geolocation API to bypass browser permission system
            (function() {
                if (navigator.geolocation) {
                    // Store original methods
                    const originalGetCurrentPosition = navigator.geolocation.getCurrentPosition;
                    const originalWatchPosition = navigator.geolocation.watchPosition;
                    const originalClearWatch = navigator.geolocation.clearWatch;
                    
                    // Override getCurrentPosition with immediate native permission check
                    navigator.geolocation.getCurrentPosition = function(successCallback, errorCallback, options) {
                        // Immediately check native permission status
                        window.ZooboxPermissionBridge.checkLocationPermission().then(function(isGranted) {
                            if (isGranted) {
                                // Permission granted, call original method directly
                                console.log('🔐 Native location permission granted, bypassing browser prompt');
                                originalGetCurrentPosition.call(navigator.geolocation, successCallback, errorCallback, options);
                            } else {
                                // Permission not granted, show custom message or call original
                                console.log('🔐 Native location permission not granted, showing prompt');
                                if (errorCallback) {
                                    errorCallback({
                                        code: 1, // PERMISSION_DENIED
                                        message: 'Location permission not granted'
                                    });
                                }
                            }
                        }).catch(function(error) {
                            console.error('🔐 Error checking location permission:', error);
                            // Fallback to original method
                            originalGetCurrentPosition.call(navigator.geolocation, successCallback, errorCallback, options);
                        });
                    };
                    
                    // Override watchPosition with immediate native permission check
                    navigator.geolocation.watchPosition = function(successCallback, errorCallback, options) {
                        // Immediately check native permission status
                        window.ZooboxPermissionBridge.checkLocationPermission().then(function(isGranted) {
                            if (isGranted) {
                                // Permission granted, call original method directly
                                console.log('🔐 Native location permission granted, bypassing browser prompt for watch');
                                return originalWatchPosition.call(navigator.geolocation, successCallback, errorCallback, options);
                            } else {
                                // Permission not granted, show custom message or call original
                                console.log('🔐 Native location permission not granted for watch');
                                if (errorCallback) {
                                    errorCallback({
                                        code: 1, // PERMISSION_DENIED
                                        message: 'Location permission not granted'
                                    });
                                }
                                return -1; // Invalid watch ID
                            }
                        }).catch(function(error) {
                            console.error('🔐 Error checking location permission for watch:', error);
                            // Fallback to original method
                            return originalWatchPosition.call(navigator.geolocation, successCallback, errorCallback, options);
                        });
                    };
                    
                    // Keep original clearWatch
                    navigator.geolocation.clearWatch = originalClearWatch;
                }
            })();
            
            // Prevent any geolocation permission dialogs by overriding permission query
            (function() {
                // Override any permission query methods that might trigger dialogs
                if (navigator.permissions) {
                    const originalQuery = navigator.permissions.query;
                    navigator.permissions.query = function(permissionDesc) {
                        if (permissionDesc.name === 'geolocation') {
                            return new Promise((resolve) => {
                                window.ZooboxPermissionBridge.checkLocationPermission().then(function(isGranted) {
                                    resolve({
                                        state: isGranted ? 'granted' : 'denied',
                                        onchange: null
                                    });
                                });
                            });
                        }
                        return originalQuery.call(navigator.permissions, permissionDesc);
                    };
                }
            })();
            
            console.log('Zoobox Permission Bridge initialized with complete geolocation override');
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        webView.configuration.userContentController.addUserScript(permissionBridgeScript)
    }
    
    private func setupGeolocationURLSchemeHandler() {
        // Add custom URL scheme handler for geolocation
        let geolocationHandler = GeolocationURLSchemeHandler()
        webView.configuration.setURLSchemeHandler(geolocationHandler, forURLScheme: "geolocation")
        
        // Inject script to intercept geolocation requests
        let geolocationInterceptScript = WKUserScript(
            source: """
            // Intercept and handle geolocation requests at the URL level
            (function() {
                // Override any geolocation-related URL requests
                const originalFetch = window.fetch;
                window.fetch = function(url, options) {
                    if (typeof url === 'string' && url.includes('geolocation')) {
                        console.log('🔐 Intercepted geolocation fetch request:', url);
                        // Return a mock response or handle differently
                        return Promise.resolve(new Response(JSON.stringify({error: 'Geolocation handled by native app'}), {
                            status: 200,
                            headers: {'Content-Type': 'application/json'}
                        }));
                    }
                    return originalFetch.apply(this, arguments);
                };
                
                // Override XMLHttpRequest for geolocation
                const originalOpen = XMLHttpRequest.prototype.open;
                XMLHttpRequest.prototype.open = function(method, url, async, user, password) {
                    if (typeof url === 'string' && url.includes('geolocation')) {
                        console.log('🔐 Intercepted geolocation XHR request:', url);
                        // Handle geolocation request differently
                        this.addEventListener('readystatechange', function() {
                            if (this.readyState === 4) {
                                this.status = 200;
                                this.responseText = JSON.stringify({error: 'Geolocation handled by native app'});
                                this.responseType = 'json';
                            }
                        });
                    }
                    return originalOpen.apply(this, arguments);
                };
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        webView.configuration.userContentController.addUserScript(geolocationInterceptScript)
    }
    
    @objc private func handleDeepLinkNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let url = userInfo["url"] as? URL else {
            print("🔗 Invalid deep link notification data")
            return
        }
        
        print("🔗 Handling FCM deep link: \(url)")
        
        // Load the deep link URL in the WebView
        DispatchQueue.main.async {
            self.loadURL(url)
        }
    }
    
    private func updateRefreshControlForConnectivity() {
        let isConnected = ConnectivityManager.shared.currentConnectivityStatus == .connected
        
        // Device-specific refresh control styling
        let fontSize: CGFloat = UIDevice.current.isIPad ? 16 : 14
        let fontWeight: UIFont.Weight = UIDevice.current.isIPad ? .semibold : .medium
        
        if !isConnected {
            refreshControl.attributedTitle = NSAttributedString(
                string: "No internet connection",
                attributes: [
                    .foregroundColor: UIColor.systemOrange,
                    .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
                ]
            )
        } else {
            refreshControl.attributedTitle = NSAttributedString(
                string: "Pull to refresh",
                attributes: [
                    .foregroundColor: UIColor.systemBlue,
                    .font: UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
                ]
            )
        }
    }
    
    func loadURL(_ url: URL) {
        print("🔄 [MainViewController] loadURL called with: \(url)")
        print("⏰ [MainViewController] loadURL time: \(Date())")
        
        // Cancel any existing timer
        loadingTimer?.invalidate()
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: loadingTimeout)
        currentNavigation = webView.load(request)
        retryCount = 0
        lastError = nil
        
        // Start loading timer
        startLoadingTimer()
        
        print("✅ [MainViewController] loadURL completed")
    }
    
    private func startLoadingTimer() {
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: loadingTimeout, repeats: false) { [weak self] _ in
            self?.handleLoadingTimeout()
        }
    }
    
    private func handleLoadingTimeout() {
        print("⏰ Loading timeout occurred")
        
        // Cancel current navigation if it exists
        if let navigation = currentNavigation {
            webView.stopLoading()
        }
        
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [
            NSLocalizedDescriptionKey: "Request timed out"
        ])
        
        handleWebViewError(timeoutError)
        
        // If refresh control is refreshing, show error
        if refreshControl.isRefreshing {
            showRefreshError()
        }
    }
    
    private func retryLoad() {
        guard retryCount < maxRetryCount else {
            showMaxRetryError()
            return
        }
        
        retryCount += 1
        print("🔄 Retrying load (attempt \(retryCount)/\(maxRetryCount))")
        
        if let currentURL = webView.url {
            loadURL(currentURL)
        } else if let url = URL(string: "https://mikmik.site") {
            loadURL(url)
        }
    }
    
    private func showMaxRetryError() {
        let alert = UIAlertController(
            title: "Connection Failed",
            message: "Unable to load the page after multiple attempts. Please check your internet connection and try again.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
            self.retryCount = 0
            self.loadMainSite()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func loadMainSite() {
        if let url = URL(string: "https://mikmik.site") {
            loadURL(url)
        }
    }
    
    private func handleWebViewError(_ error: Error) {
        lastError = error
        let nsError = error as NSError
        
        print("❌ WebView Error: \(error.localizedDescription)")
        print("❌ Error Domain: \(nsError.domain)")
        print("❌ Error Code: \(nsError.code)")
        
        // Categorize error and show appropriate message
        let errorMessage = categorizeError(error)
        showErrorAlert(title: "Loading Error", message: errorMessage)
    }
    
    private func categorizeError(_ error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.domain {
        case NSURLErrorDomain:
            return categorizeURLError(nsError)
        case "WKErrorDomain":
            return categorizeWKError(nsError)
        default:
            return "An unexpected error occurred. Please try again."
        }
    }
    
    private func categorizeURLError(_ error: NSError) -> String {
        switch error.code {
        case NSURLErrorNotConnectedToInternet:
            return "No internet connection. Please check your network settings and try again."
        case NSURLErrorNetworkConnectionLost:
            return "Network connection was lost. Please check your connection and try again."
        case NSURLErrorTimedOut:
            return "Request timed out. The server is taking too long to respond."
        case NSURLErrorCannotFindHost:
            return "Cannot find the server. Please check the URL and try again."
        case NSURLErrorCannotConnectToHost:
            return "Cannot connect to the server. The server may be down or unreachable."
        case NSURLErrorBadServerResponse:
            return "Server error. The server returned an invalid response."
        case NSURLErrorUnsupportedURL:
            return "Unsupported URL format. Please check the address."
        case NSURLErrorSecureConnectionFailed:
            return "Secure connection failed. There may be a security issue with the server."
        default:
            return "Network error occurred. Please try again."
        }
    }
    
    private func categorizeWKError(_ error: NSError) -> String {
        switch error.code {
        case 102: // WKErrorFrameLoadInterruptedByPolicyChange
            return "Page load was interrupted. Please try again."
        case 103: // WKErrorCannotShowURL
            return "Cannot display this URL. The content may not be supported."
        case 104: // WKErrorCancelled
            return "Request was cancelled. Please try again."
        case 105: // WKErrorJavaScriptExceptionOccurred
            return "A JavaScript error occurred on the page."
        case 106: // WKErrorJavaScriptResultTypeIsUnsupported
            return "JavaScript result type is not supported."
        default:
            return "Web page error occurred. Please try again."
        }
    }
    
    private func showErrorAlert(title: String, message: String) {
        // Device-specific alert styling
        let alertStyle: UIAlertController.Style = UIDevice.current.isIPad ? .alert : .alert
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: alertStyle)
        
        // Device-specific button styling
        let retryAction = UIAlertAction(title: "Retry", style: .default) { _ in
            self.retryLoad()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(retryAction)
        alert.addAction(cancelAction)
        
        // iPad-specific popover presentation
        if UIDevice.current.isIPad {
            if let popover = alert.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Authentication Error Handling
    
    func isAuthenticationError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        let errorDomain = (error as NSError).domain
        let errorCode = (error as NSError).code
        
        // Enhanced authentication error detection for iPad
        let isAuth = errorDescription.contains("sign") ||
                    errorDescription.contains("login") ||
                    errorDescription.contains("authentication") ||
                    errorDescription.contains("unauthorized") ||
                    errorDescription.contains("forbidden") ||
                    errorDescription.contains("session") ||
                    errorDescription.contains("credential") ||
                    errorDomain.contains("authentication") ||
                    errorCode == 401 ||
                    errorCode == 403 ||
                    errorCode == 498 || // Token expired
                    errorCode == 499    // Token required
        
        if isAuth {
            print("🔐 [iPad Auth] Authentication error detected: \(error)")
            print("🔐 [iPad Auth] Error domain: \(errorDomain)")
            print("🔐 [iPad Auth] Error code: \(errorCode)")
            print("🔐 [iPad Auth] Error description: \(errorDescription)")
        }
        
        return isAuth
    }
    
    func handleAuthenticationError(_ error: Error) {
        print("🔐 [iPad Auth] Handling authentication error: \(error)")
        
        // Show user-friendly authentication error with iPad-specific handling
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create iPad-optimized error message
            let title = "Connection Issue"
            let message = UIDevice.current.isIPad ? 
                "There was a temporary issue connecting to Zoobox on your iPad. Please try again in a moment." :
                "There was a temporary issue connecting to Zoobox. Please try again in a moment."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            // Add retry action with iPad-specific delay
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                // Add iPad-specific retry delay
                let retryDelay = UIDevice.current.isIPad ? 2.0 : 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                    self.retryLoad()
                }
            })
            
            // Add cancel action
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            // iPad-specific popover presentation
            if UIDevice.current.isIPad {
                if let popover = alert.popoverPresentationController {
                    popover.sourceView = self.view
                    popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
            }
            
            self.present(alert, animated: true)
        }
    }
    
    // MARK: - Helper Methods for WKScriptMessageHandler
    
    func handleHapticFeedback(message: WKScriptMessage) {
        guard let feedbackType = message.body as? String else { return }
        
        print("📱 [HapticFeedback] Triggering \(feedbackType) haptic feedback")
        
        DispatchQueue.main.async {
            switch feedbackType {
            case "light":
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            case "medium":
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            case "heavy":
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
            case "success":
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.success)
            case "warning":
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.warning)
            case "error":
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.notificationOccurred(.error)
            default:
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    func handlePermissionBridge(message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            print("🔐 Invalid permission bridge message")
            return
        }
        
        switch action {
        case "checkPermission":
            handleCheckPermission(body)
        case "getAllPermissions":
            handleGetAllPermissions()
        default:
            print("🔐 Unknown permission bridge action: \(action)")
        }
    }
    
    func handleCheckPermission(_ body: [String: Any]) {
        guard let permissionType = body["permissionType"] as? String else {
            print("🔐 Missing permission type in checkPermission")
            return
        }
        
        // Handle location permission on main thread to avoid crashes
        if permissionType == "location" {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    print("🔐 Self is nil, skipping permission response")
                    return
                }
                
                guard let webView = self.webView else {
                    print("🔐 WebView is nil, skipping permission response")
                    return
                }
                
                // Additional safety check - ensure WebView has a valid URL
                guard webView.url != nil else {
                    print("🔐 WebView URL is nil, skipping permission response")
                    return
                }
                
                let locationStatus = CLLocationManager.authorizationStatus()
                let isGranted = locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse
                
                let responseScript = "if (window.ZooboxPermissionBridge && window.ZooboxPermissionBridge._resolvePermission) { window.ZooboxPermissionBridge._resolvePermission('\(permissionType)', \(isGranted)); } else { console.log('🔐 ZooboxPermissionBridge not ready yet'); }"
                
                // Add a small delay to ensure JavaScript bridge is fully initialized
                let executeScript = {
                    // Use the safer JavaScript execution method
                    self.executeSafeJavaScript(responseScript)
                }
                
                // Execute immediately if WebView is loaded, otherwise add a small delay
                if self.isWebViewLoaded {
                    executeScript()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        executeScript()
                    }
                }
                
                print("🔐 Permission check for \(permissionType): \(isGranted)")
            }
        } else {
            // Handle other permissions on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let isGranted: Bool
                switch permissionType {
                case "camera":
                    isGranted = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
                case "microphone":
                    isGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
                default:
                    isGranted = false
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        print("🔐 Self is nil, skipping permission response")
                        return
                    }
                    
                    guard let webView = self.webView else {
                        print("🔐 WebView is nil, skipping permission response")
                        return
                    }
                    
                    // Additional safety check - ensure WebView has a valid URL
                    guard webView.url != nil else {
                        print("🔐 WebView URL is nil, skipping permission response")
                        return
                    }
                    
                    let responseScript = "if (window.ZooboxPermissionBridge && window.ZooboxPermissionBridge._resolvePermission) { window.ZooboxPermissionBridge._resolvePermission('\(permissionType)', \(isGranted)); } else { console.log('🔐 ZooboxPermissionBridge not ready yet'); }"
                    
                    // Add a small delay to ensure JavaScript bridge is fully initialized
                    let executeScript = {
                        // Use the safer JavaScript execution method
                        self.executeSafeJavaScript(responseScript)
                    }
                    
                    // Execute immediately if WebView is loaded, otherwise add a small delay
                    if self.isWebViewLoaded {
                        executeScript()
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            executeScript()
                        }
                    }
                    
                    print("🔐 Permission check for \(permissionType): \(isGranted)")
                }
            }
        }
    }
    
    func handleGetAllPermissions() {
        // Get location permission on main thread first
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("🔐 Self is nil, skipping all permissions response")
                return
            }
            
            guard let webView = self.webView else {
                print("🔐 WebView is nil, skipping all permissions response")
                return
            }
            
            // Additional safety check - ensure WebView has a valid URL
            guard webView.url != nil else {
                print("🔐 WebView URL is nil, skipping all permissions response")
                return
            }
            
            let locationStatus = CLLocationManager.authorizationStatus()
            let locationGranted = locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse
            
            // Get other permissions on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let permissions: [String: Bool] = [
                    "camera": AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                    "location": locationGranted,
                    "microphone": AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
                ]
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        print("🔐 Self is nil, skipping all permissions response")
                        return
                    }
                    
                    guard let webView = self.webView else {
                        print("🔐 WebView is nil, skipping all permissions response")
                        return
                    }
                    
                    // Additional safety check - ensure WebView has a valid URL
                    guard webView.url != nil else {
                        print("🔐 WebView URL is nil, skipping all permissions response")
                        return
                    }
                    
                    if let jsonData = try? JSONSerialization.data(withJSONObject: permissions),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        let responseScript = "if (window.ZooboxPermissionBridge && window.ZooboxPermissionBridge._resolveAllPermissions) { window.ZooboxPermissionBridge._resolveAllPermissions(\(jsonString)); } else { console.log('🔐 ZooboxPermissionBridge not ready yet'); }"
                        
                        if self.isWebViewLoaded && webView.url != nil {
                            // Use the safer JavaScript execution method
                            self.executeSafeJavaScript(responseScript)
                        } else {
                            if !self.pendingJSResponses.contains(responseScript) {
                                self.pendingJSResponses.append(responseScript)
                            }
                        }
                    }
                    print("🔐 All permissions status: \(permissions)")
                }
            }
        }
    }
    
    // Add a retry mechanism for permission bridge JavaScript execution
    private func executeJavaScriptWithRetry(_ script: String, retryCount: Int = 0, maxRetries: Int = 3) {
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.executeJavaScriptWithRetry(script, retryCount: retryCount, maxRetries: maxRetries)
            }
            return
        }
        
        guard let webView = self.webView else {
            print("🔐 WebView is nil, cannot execute JavaScript")
            return
        }
        
        guard webView.url != nil else {
            print("🔐 WebView URL is nil, cannot execute JavaScript")
            return
        }
        
        // Additional safety checks
        guard !webView.isLoading else {
            print("🔐 WebView is still loading, delaying JavaScript execution")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.executeJavaScriptWithRetry(script, retryCount: retryCount, maxRetries: maxRetries)
            }
            return
        }
        
        // Check if WebView has a valid navigation state
        guard webView.canGoBack || webView.canGoForward || webView.url?.absoluteString.contains("mikmik.site") == true else {
            print("🔐 WebView navigation state invalid, delaying JavaScript execution")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.executeJavaScriptWithRetry(script, retryCount: retryCount, maxRetries: maxRetries)
            }
            return
        }
        
        // Wrap in a try-catch equivalent using objective-c exception handling
        autoreleasepool {
            // First, test if the WebView can execute JavaScript at all
            let testScript = "typeof window !== 'undefined'"
            
            webView.evaluateJavaScript(testScript) { [weak self] testResult, testError in
                guard let self = self else { return }
                
                if let testError = testError {
                    print("🔐 WebView JavaScript context test failed: \(testError)")
                    
                    if retryCount < maxRetries {
                        print("🔐 Retrying JavaScript execution (attempt \(retryCount + 1)/\(maxRetries + 1))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.executeJavaScriptWithRetry(script, retryCount: retryCount + 1, maxRetries: maxRetries)
                        }
                    } else {
                        print("🔐 Failed to execute JavaScript after \(maxRetries + 1) attempts, adding to pending")
                        if !self.pendingJSResponses.contains(script) {
                            self.pendingJSResponses.append(script)
                        }
                    }
                    return
                }
                
                // If test passed, execute the actual script
                webView.evaluateJavaScript(script) { [weak self] result, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("🔐 Error executing JavaScript (attempt \(retryCount + 1)/\(maxRetries + 1)): \(error)")
                        
                        if retryCount < maxRetries {
                            // Retry after a longer delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.executeJavaScriptWithRetry(script, retryCount: retryCount + 1, maxRetries: maxRetries)
                            }
                        } else {
                            print("🔐 Failed to execute JavaScript after \(maxRetries + 1) attempts")
                            // Add to pending responses as last resort
                            if !self.pendingJSResponses.contains(script) {
                                self.pendingJSResponses.append(script)
                            }
                        }
                    } else {
                        print("🔐 Successfully executed JavaScript")
                    }
                }
            }
        }
    }
    
    // Check if WebView is fully ready for JavaScript execution
    // SIMPLIFIED VERSION: Skips JavaScript testing to avoid hangs
    private func checkWebViewReadiness() {
        print("🔐 [WebViewReadiness] Using simplified readiness check")
        
        guard let webView = self.webView else {
            print("🔐 [WebViewReadiness] WebView is nil, marking as not ready")
            isWebViewFullyReady = false
            return
        }
        
        guard webView.url != nil, !webView.isLoading else {
            print("🔐 [WebViewReadiness] WebView URL is nil or still loading, marking as not ready")
            isWebViewFullyReady = false
            return
        }
        
        // Skip the problematic JavaScript testing and mark as ready immediately
        print("🔐 [WebViewReadiness] WebView appears loaded, marking as ready without JavaScript testing")
        isWebViewFullyReady = true
        
        // Process any pending JavaScript
        processPendingJavaScript()
        
        print("🔐 [WebViewReadiness] ✅ WebView marked as ready (simplified)")
        return
    }
    
    // LEGACY: Complex readiness check with JavaScript testing (DISABLED due to hangs)
    private func checkWebViewReadinessWithJSTesting() {
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.checkWebViewReadiness()
            }
            return
        }
        
        print("🔐 [WebViewReadiness] Starting readiness check")
        
        guard let webView = self.webView else {
            print("🔐 [WebViewReadiness] WebView is nil, marking as not ready")
            isWebViewFullyReady = false
            return
        }
        
        guard webView.url != nil, !webView.isLoading else {
            print("🔐 [WebViewReadiness] WebView URL is nil or still loading, marking as not ready")
            isWebViewFullyReady = false
            return
        }
        
        print("🔐 [WebViewReadiness] WebView appears ready, testing JavaScript context")
        
        // Add a small delay to ensure the WebView has fully committed the navigation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            guard let webView = self.webView else {
                print("🔐 [WebViewReadiness] WebView became nil during delay")
                self.isWebViewFullyReady = false
                return
            }
            
            // Test if JavaScript context is available with a simpler test first
            let testScript = "typeof window"
            print("🔐 [WebViewReadiness] Testing JavaScript context with: \(testScript)")
            
            // Add timeout protection for JavaScript evaluation
            var hasResponded = false
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if !hasResponded {
                    print("🔐 [WebViewReadiness] ⚠️ JavaScript evaluation timed out after 3 seconds!")
                    hasResponded = true // Prevent duplicate calls
                    self.handleReadinessTimeout()
                }
            }
            
            webView.evaluateJavaScript(testScript) { [weak self] result, error in
                guard let self = self else { return }
                
                hasResponded = true
                timeoutTimer.invalidate()
                
                if let error = error {
                    print("🔐 [WebViewReadiness] JavaScript context test failed: \(error)")
                    self.isWebViewFullyReady = false
                    
                    // Schedule another check with a longer delay
                    self.webViewReadyTimer?.invalidate()
                    self.webViewReadyTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                        print("🔐 [WebViewReadiness] Retrying readiness check after error")
                        self.checkWebViewReadiness()
                    }
                    return
                }
                
                print("🔐 [WebViewReadiness] Basic JavaScript test passed: \(result ?? "nil")")
                
                // If basic test passed, try the full test
                let fullTestScript = "typeof window !== 'undefined' && typeof document !== 'undefined'"
                print("🔐 [WebViewReadiness] Testing full JavaScript context with: \(fullTestScript)")
                
                var fullTestResponded = false
                let fullTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    if !fullTestResponded {
                        print("🔐 [WebViewReadiness] ⚠️ Full JavaScript evaluation timed out after 3 seconds!")
                        fullTestResponded = true // Prevent duplicate calls
                        self.handleReadinessTimeout()
                    }
                }
                
                webView.evaluateJavaScript(fullTestScript) { [weak self] fullResult, fullError in
                    guard let self = self else { return }
                    
                    fullTestResponded = true
                    fullTimeoutTimer.invalidate()
                    
                    if fullError == nil, let isReady = fullResult as? Bool, isReady {
                        self.isWebViewFullyReady = true
                        print("🔐 [WebViewReadiness] ✅ WebView is fully ready for JavaScript execution!")
                        
                        // Process any pending JavaScript
                        self.processPendingJavaScript()
                    } else {
                        print("🔐 [WebViewReadiness] Full JavaScript test failed: \(fullError?.localizedDescription ?? "unknown result")")
                        print("🔐 [WebViewReadiness] Full result: \(fullResult ?? "nil")")
                        self.isWebViewFullyReady = false
                        
                        // Schedule another check
                        self.webViewReadyTimer?.invalidate()
                        self.webViewReadyTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                            print("🔐 [WebViewReadiness] Retrying readiness check after full test failure")
                            self.checkWebViewReadiness()
                        }
                    }
                }
            }
        }
    }
    
    // Handle readiness check timeouts
    private func handleReadinessTimeout() {
        print("🔐 [WebViewReadiness] ⚠️ Timeout occurred, forcing ready state")
        
        // Cancel any existing timer to prevent duplicate calls
        webViewReadyTimer?.invalidate()
        webViewReadyTimer = nil
        
        // Force ready state
        isWebViewFullyReady = true
        
        // Process any pending JavaScript with timeout protection
        processPendingJavaScript()
        
        print("🔐 [WebViewReadiness] ✅ Ready state forced due to timeout")
    }
    
    // Process pending JavaScript when WebView is ready
    // DISABLED: ALL JavaScript evaluation disabled to prevent EXC_BAD_ACCESS crashes
    private func processPendingJavaScript() {
        print("🔐 [PendingJS] DISABLED: Processing pending JavaScript disabled to prevent EXC_BAD_ACCESS crashes")
        
        if !pendingJSResponses.isEmpty {
            print("🔐 [PendingJS] DISABLED: \(pendingJSResponses.count) JavaScript calls were queued but not executed")
            for (index, script) in pendingJSResponses.enumerated() {
                print("🔐 [PendingJS] DISABLED: Script \(index + 1): \(script.prefix(50))...")
            }
        }
        
        // Clear pending responses without executing them to prevent crashes
        pendingJSResponses.removeAll()
        print("🔐 [PendingJS] DISABLED: Cleared all pending JavaScript calls without execution")
        
        /* DISABLED CODE THAT WAS CAUSING EXC_BAD_ACCESS CRASHES:
        
        guard isWebViewFullyReady, let webView = self.webView else { 
            print("🔐 [PendingJS] Cannot process pending JavaScript - WebView not ready or nil")
            return 
        }
        
        print("🔐 [PendingJS] Processing \(pendingJSResponses.count) pending JavaScript calls")
        
        for (index, script) in pendingJSResponses.enumerated() {
            autoreleasepool {
                print("🔐 [PendingJS] Executing script \(index + 1)/\(pendingJSResponses.count): \(script.prefix(50))...")
                webView.evaluateJavaScript(script) { result, error in
                    if let error = error {
                        print("🔐 [PendingJS] Error executing script \(index + 1): \(error)")
                    } else {
                        print("🔐 [PendingJS] Successfully executed script \(index + 1)")
                    }
                }
            }
        }
        
        pendingJSResponses.removeAll()
        print("🔐 [PendingJS] Cleared all pending JavaScript calls")
        
        */
    }
    
    // Manual debug method to check WebView state and force readiness check
    func debugWebViewState() {
        print("🔐 [DEBUG] =================== WebView State Debug ===================")
        print("🔐 [DEBUG] WebView: \(webView != nil ? "EXISTS" : "NIL")")
        print("🔐 [DEBUG] WebView URL: \(webView?.url?.absoluteString ?? "nil")")
        print("🔐 [DEBUG] WebView isLoading: \(webView?.isLoading ?? false)")
        print("🔐 [DEBUG] isWebViewLoaded: \(isWebViewLoaded)")
        print("🔐 [DEBUG] isWebViewFullyReady: \(isWebViewFullyReady)")
        print("🔐 [DEBUG] pendingJSResponses count: \(pendingJSResponses.count)")
        print("🔐 [DEBUG] webViewReadyTimer: \(webViewReadyTimer != nil ? "ACTIVE" : "NIL")")
        
        if !pendingJSResponses.isEmpty {
            print("🔐 [DEBUG] Pending JavaScript calls:")
            for (index, script) in pendingJSResponses.enumerated() {
                print("🔐 [DEBUG]   \(index + 1). \(script.prefix(100))...")
            }
        }
        
        // Force readiness check
        print("🔐 [DEBUG] Forcing readiness check...")
        checkWebViewReadiness()
        
        print("🔐 [DEBUG] ========================================================")
    }
    
    // Convenience method to manually force WebView readiness - call from debugger
    func forceWebViewReady() {
        print("🔐 [FORCE] Manually forcing WebView ready state")
        
        // Cancel any ongoing timers
        webViewReadyTimer?.invalidate()
        webViewReadyTimer = nil
        
        // Force ready state
        isWebViewFullyReady = true
        processPendingJavaScript()
    }
    
    // Fallback method that skips JavaScript testing entirely
    func forceWebViewReadyWithoutJS() {
        print("🔐 [FALLBACK] Forcing WebView ready without JavaScript testing")
        
        guard let webView = self.webView else {
            print("🔐 [FALLBACK] WebView is nil, cannot force ready")
            return
        }
        
        guard webView.url != nil else {
            print("🔐 [FALLBACK] WebView URL is nil, cannot force ready")
            return
        }
        
        // Cancel any ongoing timers
        webViewReadyTimer?.invalidate()
        webViewReadyTimer = nil
        
        // Skip all JavaScript testing and force ready
        isWebViewFullyReady = true
        
        print("🔐 [FALLBACK] ✅ WebView forced ready without JavaScript testing")
        
        // Process pending JavaScript if any
        processPendingJavaScript()
    }
    
    // Test JavaScript execution directly - call from debugger
    // DISABLED: ALL JavaScript evaluation disabled to prevent EXC_BAD_ACCESS crashes
    func testJavaScriptExecution() {
        print("🔐 [TEST] DISABLED: JavaScript testing disabled to prevent EXC_BAD_ACCESS crashes")
        print("🔐 [TEST] DISABLED: WebView JavaScript evaluation causes memory access violations")
        print("🔐 [TEST] DISABLED: Use native iOS APIs instead of JavaScript for functionality")
        
        /* DISABLED CODE THAT WAS CAUSING EXC_BAD_ACCESS CRASHES:
        
        guard let webView = self.webView else {
            print("🔐 [TEST] WebView is nil, cannot test JavaScript")
            return
        }
        
        print("🔐 [TEST] Testing direct JavaScript execution...")
        
        let testScript = "typeof window"
        webView.evaluateJavaScript(testScript) { result, error in
            if let error = error {
                print("🔐 [TEST] ❌ JavaScript execution failed: \(error)")
            } else {
                print("🔐 [TEST] ✅ JavaScript execution succeeded: \(result ?? "nil")")
            }
        }
        
        */
    }
    
    // Safe JavaScript execution that waits for WebView readiness
    // DISABLED: ALL JavaScript evaluation disabled to prevent EXC_BAD_ACCESS crashes
    private func executeSafeJavaScript(_ script: String) {
        // CRITICAL: JavaScript evaluation in WebView causes EXC_BAD_ACCESS crashes
        // Completely disabled to prevent app crashes
        print("🔐 [SafeJS] DISABLED: JavaScript execution disabled to prevent EXC_BAD_ACCESS crashes")
        print("🔐 [SafeJS] DISABLED: Script would have been: \(script.prefix(100))...")
        print("🔐 [SafeJS] DISABLED: WebView JavaScript evaluation causes memory access violations")
        
        // Do not execute any JavaScript to prevent crashes
        return
        
        /* DISABLED CODE THAT WAS CAUSING EXC_BAD_ACCESS CRASHES:
        
        // Ensure we're on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.executeSafeJavaScript(script)
            }
            return
        }
        
        guard let webView = self.webView else {
            print("🔐 [SafeJS] WebView is nil, cannot execute JavaScript")
            return
        }
        
        guard webView.url != nil else {
            print("🔐 [SafeJS] WebView URL is nil, adding script to pending queue")
            if !pendingJSResponses.contains(script) {
                pendingJSResponses.append(script)
            }
            return
        }
        
        if isWebViewFullyReady {
            // Execute immediately with timeout protection
            print("🔐 [SafeJS] Executing JavaScript: \(script.prefix(50))...")
            autoreleasepool {
                webView.evaluateJavaScript(script) { result, error in
                    if let error = error {
                        print("🔐 [SafeJS] Error executing JavaScript: \(error)")
                    } else {
                        print("🔐 [SafeJS] Successfully executed JavaScript")
                    }
                }
            }
        } else {
            // Add to pending queue - simplified approach will process it soon
            if !pendingJSResponses.contains(script) {
                pendingJSResponses.append(script)
                print("🔐 [SafeJS] Added JavaScript to pending queue (WebView not ready yet)")
            }
            
            // Force ready state after short delay if needed
            if webViewReadyTimer == nil {
                webViewReadyTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    print("🔐 [SafeJS] Forcing ready state due to pending JavaScript")
                    self.forceWebViewReadyWithoutJS()
                }
            }
        }
        
        */
    }
    
    // Test geolocation functionality for debugging
    private func testGeolocationAvailability() {
        print("🔐 [DISABLED] testGeolocationAvailability() called but disabled to prevent EXC_BAD_ACCESS crashes")
        print("🔐 [DISABLED] JavaScript evaluation in WebView can cause memory access violations")
        
        guard let webView = self.webView else {
            print("🔐 Cannot test geolocation - WebView is nil")
            return
        }
        
        // Only do safe, non-JavaScript tests
        let locationStatus = CLLocationManager.authorizationStatus()
        print("🔐 Native location permission status: \(locationStatus)")
        
        // Skip all JavaScript evaluation calls as they cause EXC_BAD_ACCESS crashes
        print("🔐 Skipping all JavaScript geolocation tests to prevent crashes")
        
        /* DISABLED - ALL JAVASCRIPT CALLS THAT WERE CAUSING CRASHES:
        
        // Test 1: Check if navigator.geolocation exists
        webView.evaluateJavaScript("typeof navigator.geolocation") { result, error in
            if let error = error {
                print("🔐 Geolocation test 1 error: \(error)")
            } else {
                print("🔐 navigator.geolocation type: \(result as? String ?? "unknown")")
            }
        }
        
        // Test 2: Check if getCurrentPosition exists
        webView.evaluateJavaScript("typeof navigator.geolocation.getCurrentPosition") { result, error in
            if let error = error {
                print("🔐 Geolocation test 2 error: \(error)")
            } else {
                print("🔐 navigator.geolocation.getCurrentPosition type: \(result as? String ?? "unknown")")
            }
        }
        
        // Test 3: Check if our permission bridge exists
        webView.evaluateJavaScript("typeof window.ZooboxPermissionBridge") { result, error in
            if let error = error {
                print("🔐 Permission bridge test error: \(error)")
            } else {
                print("🔐 ZooboxPermissionBridge type: \(result as? String ?? "unknown")")
            }
        }
        
        // Test 5: Try to get location permission status through bridge
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            webView.evaluateJavaScript("window.ZooboxPermissionBridge ? window.ZooboxPermissionBridge.checkLocationPermission() : 'bridge not available'") { result, error in
                if let error = error {
                    print("🔐 Permission bridge location check error: \(error)")
                } else {
                    print("🔐 Permission bridge location check result: \(result ?? "nil")")
                }
            }
        }
        
        */
    }
    
    // MARK: - Safe Permission Management
    
    // Request native location permission safely
    private func requestNativeLocationPermission(completion: @escaping (Bool) -> Void) {
        print("🔐 [Permission] REMOVED: Native permission request disabled by user request")
        print("🔐 [Permission] WebView will handle all permission requests using standard prompts")
        
        // REMOVED: All native permission request functionality
        // - No CLLocationManager setup
        // - No permission delegate handling
        // - WebView will use standard permission flow
        
        completion(false) // Always return false since we're not handling permissions
    }
    
    // Safely inject permission status into WebView without evaluateJavaScript
    private func injectPermissionStatusSafely() {
        print("🔐 [Permission] REMOVED: All permission injection functionality removed by user request")
        print("🔐 [Permission] WebView will handle permissions using standard browser behavior")
        
        // REMOVED: All permission injection code removed
        // - No JavaScript injection
        // - No UserScript injection  
        // - No cookie-based permission forwarding
        // - WebView will use standard permission prompts
        
        print("🔐 [Permission] ✅ Permission system disabled - using standard WebView behavior")
    }
    
    // Set permission status as cookie
    private func setPermissionCookie(type: String, granted: Bool) {
        print("🔐 [Cookie] REMOVED: Cookie-based permission system disabled by user request")
        print("🔐 [Cookie] No permission cookies will be set")
        
        // REMOVED: All cookie-based permission functionality
        // - No zoobox_permission_location cookies
        // - No automatic cookie setting
        // - WebView will handle permissions natively
        
        print("🔐 [Cookie] ✅ Cookie permission system disabled")
    }
    
    // Inject permission status via UserScript (runs when page loads)
    private func injectPermissionUserScript(locationGranted: Bool) {
        print("🔐 [UserScript] REMOVED: UserScript injection disabled by user request")
        print("🔐 [UserScript] No JavaScript will be injected into WebView")
        
        // REMOVED: All UserScript injection functionality
        // - No window.zooboxPermissions injection
        // - No custom event dispatching
        // - No permission status scripts
        // - WebView will use standard JavaScript environment
        
        print("🔐 [UserScript] ✅ UserScript injection disabled")
    }
    
    // Trigger permission update (safe page refresh)
    private func triggerPermissionUpdate() {
        print("🔐 [Permission] DISABLED: Page refresh disabled to prevent infinite loading loop")
        print("🔐 [Permission] Permissions are now set via cookies without page refresh")
        
        // DISABLED: This was causing infinite loading loop
        // guard let webView = self.webView else { return }
        // 
        // print("🔐 [Permission] Triggering permission update")
        // 
        // // Trigger a gentle reload to ensure new permissions are recognized
        // if let currentURL = webView.url {
        //     print("🔐 [Permission] Refreshing current page to update permissions")
        //     webView.load(URLRequest(url: currentURL))
        // }
    }
    
    // Setup WebView user scripts (haptic, viewport, etc.)
    private func setupWebViewUserScripts() {
        guard let webView = self.webView else { return }
        
        let userContentController = webView.configuration.userContentController
        
        // SAFETY: Remove existing handler first to prevent "already exists" crash
        userContentController.removeScriptMessageHandler(forName: "hapticFeedback")
        
        // Re-add haptic feedback handler safely
        userContentController.add(self, name: "hapticFeedback")
        
        // Note: Other scripts (viewport, CSS, haptic) are added during WebView setup
        // This method ensures they're preserved when we update permission scripts
    }
    
    // Test method to manually check geolocation permission status - call from debugger
    func testLocationPermissionForWebView() {
        print("🔐 [TEST] 🌍 TESTING LOCATION PERMISSION STATUS")
        print("🔐 [TEST] ==========================================")
        
        let locationStatus = CLLocationManager.authorizationStatus()
        print("🔐 [TEST] Native iOS location status: \(locationStatus.rawValue)")
        print("🔐 [TEST] Status description: \(locationStatusDescription(locationStatus))")
        
        let isGranted = locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse
        print("🔐 [TEST] Is location granted: \(isGranted)")
        
        if let webView = self.webView {
            print("🔐 [TEST] WebView exists: ✅")
            print("🔐 [TEST] WebView URL: \(webView.url?.absoluteString ?? "nil")")
            
            // Check if there are any cookies set
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                print("🔐 [TEST] Total cookies: \(cookies.count)")
                let permissionCookies = cookies.filter { $0.name.contains("zoobox_permission") }
                print("🔐 [TEST] Permission cookies: \(permissionCookies.count)")
                
                for cookie in permissionCookies {
                    print("🔐 [TEST] Cookie: \(cookie.name) = \(cookie.value)")
                }
            }
        } else {
            print("🔐 [TEST] WebView exists: ❌")
        }
        
        print("🔐 [TEST] ==========================================")
    }
    
    // Helper method to describe location status
    private func locationStatusDescription(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Authorized Always"
        case .authorizedWhenInUse:
            return "Authorized When In Use"
        @unknown default:
            return "Unknown"
        }
    }
    
    // Debug method to test what the website can see - call from debugger
    func debugWebsitePermissions() {
        print("🔐 [DEBUG] REMOVED: Debug methods removed - permission system disabled")
        print("🔐 [DEBUG] WebView now uses standard behavior only")
    }
    
    
}

// MARK: - WKNavigationDelegate
extension MainViewController {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("🔄 [WebView] didStartProvisionalNavigation called")
        print("⏰ [WebView] didStartProvisionalNavigation time: \(Date())")
        print("📱 [WebView] Device: \(UIDevice.current.deviceFamily)")
        print("📱 [WebView] Orientation: \(UIDevice.current.orientationString)")
        print("📱 [WebView] Screen size: \(UIScreen.main.bounds.size)")
        print("🔐 [WebView] URL: \(webView.url?.absoluteString ?? "nil")")
        
        // Reset WebView readiness state
        isWebViewFullyReady = false
        webViewReadyTimer?.invalidate()
        
        currentNavigation = navigation
        startLoadingTimer()
        
        // Keep loading indicator visible during webview loading
        print("📱 [WebView] Keeping loading indicator visible during webview loading")
        
        print("✅ [WebView] didStartProvisionalNavigation completed")
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("📄 WebView committed navigation")
        print("🔐 [WebView] Committed URL: \(webView.url?.absoluteString ?? "nil")")
        
        // DISABLED: Test geolocation availability after commit
        // This JavaScript evaluation was causing EXC_BAD_ACCESS crashes
        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        //     webView.evaluateJavaScript("typeof navigator.geolocation !== 'undefined'") { result, error in
        //         if let error = error {
        //             print("🔐 Geolocation availability check error: \(error)")
        //         } else {
        //             print("🔐 Geolocation available in WebView: \(result as? Bool ?? false)")
        //         }
        //     }
        // }
        
        // Instead, just log that geolocation is assumed available
        print("🔐 Geolocation assumed available in WebView (skipping JavaScript test)")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Ensure we're on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isWebViewLoaded = true
            
            print("✅ [WebView] didFinish called - WebView loaded successfully")
            print("⏰ [WebView] didFinish time: \(Date())")
            print("📱 [WebView] Device: \(UIDevice.current.deviceFamily)")
            print("📱 [WebView] Orientation: \(UIDevice.current.orientationString)")
            print("📱 [WebView] Screen size: \(UIScreen.main.bounds.size)")
            print("🔐 [WebView] Final URL: \(webView.url?.absoluteString ?? "nil")")
            
            // Cancel loading timer
            self.loadingTimer?.invalidate()
            
            // Reset error state on successful load
            self.lastError = nil
            self.retryCount = 0
            
            // ALWAYS hide loading indicator when webview finishes loading
            print("📱 [WebView] Hiding loading indicator - webview finished loading")
            LoadingIndicatorManager.shared.hideLoadingIndicator()
            
            // SIMPLIFIED: Skip JavaScript readiness check and mark as ready immediately
            // The complex JavaScript testing was causing hangs, so we use a simpler approach
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                
                print("🔐 [SIMPLIFIED] Marking WebView as ready without JavaScript testing")
                self.isWebViewFullyReady = true
                
                // Process any pending JavaScript
                self.processPendingJavaScript()
                
                print("🔐 [SIMPLIFIED] ✅ WebView ready state set")
                
                // REMOVED: Auto-inject that was causing loading loop
                // print("🔐 [AutoInject] Automatically injecting permissions into new page")
                // self.injectPermissionStatusSafely()
                
                print("🔐 [AutoInject] DISABLED: Auto-injection disabled to prevent loading loop")
            }
            
            // If refresh control is refreshing, show success
            if self.refreshControl.isRefreshing {
                self.showRefreshSuccess()
            }
            
            // Trigger location update on webview refresh
            LocationUpdateService.shared.onWebViewRefresh()
            
            print("✅ [WebView] didFinish completed")
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView failed to load: \(error)")
        print("❌ Error domain: \((error as NSError).domain)")
        print("❌ Error code: \((error as NSError).code)")
        print("❌ Error description: \(error.localizedDescription)")
        
        // iPad-specific error logging
        if UIDevice.current.isIPad {
            print("📱 [iPad] WebView error on iPad device")
            print("📱 [iPad] Device: \(UIDevice.current.model)")
            print("📱 [iPad] iOS Version: \(UIDevice.current.systemVersion)")
        }
        
        // Cancel loading timer
        loadingTimer?.invalidate()
        
        // Hide loading indicator when webview fails
        print("📱 [WebView] Hiding loading indicator - webview failed")
        LoadingIndicatorManager.shared.hideLoadingIndicator()
        
        // Enhanced error handling for iPad
        let nsError = error as NSError
        
        // Check for authentication/sign-in errors with iPad-specific handling
        if isAuthenticationError(error) {
            handleAuthenticationError(error)
            return
        }
        
        // iPad-specific error recovery
        if UIDevice.current.isIPad && nsError.domain == "WebKitErrorDomain" && nsError.code == 102 {
            // Frame load interrupted on iPad - attempt recovery
            print("📱 [iPad] Frame load interrupted - attempting recovery")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.retryLoad()
            }
            return
        }
        
        // Handle other errors normally
        handleWebViewError(error)
        
        // If refresh control is refreshing, show error
        if refreshControl.isRefreshing {
            showRefreshError()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ WebView failed to load (provisional): \(error)")
        print("❌ Provisional error domain: \((error as NSError).domain)")
        print("❌ Provisional error code: \((error as NSError).code)")
        print("❌ Provisional error description: \(error.localizedDescription)")
        
        // iPad-specific provisional error logging
        if UIDevice.current.isIPad {
            print("📱 [iPad] Provisional navigation error on iPad device")
            print("📱 [iPad] This may be related to iPad-specific WebView behavior")
        }
        
        // Cancel loading timer
        loadingTimer?.invalidate()
        
        // Hide loading indicator when webview fails
        print("📱 [WebView] Hiding loading indicator - webview failed (provisional)")
        LoadingIndicatorManager.shared.hideLoadingIndicator()
        
        // Enhanced provisional error handling for iPad
        let nsError = error as NSError
        
        // Check for authentication/sign-in errors with iPad-specific handling
        if isAuthenticationError(error) {
            handleAuthenticationError(error)
            return
        }
        
        // iPad-specific provisional error recovery
        if UIDevice.current.isIPad && nsError.domain == "NSURLErrorDomain" && nsError.code == -1001 {
            // Timeout on iPad - use longer timeout
            print("📱 [iPad] Request timeout - using iPad-specific retry logic")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.retryLoad()
            }
            return
        }
        
        // Handle other errors normally
        handleWebViewError(error)
        
        // If refresh control is refreshing, show error
        if refreshControl.isRefreshing {
            showRefreshError()
        }
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("🔄 WebView received server redirect")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Allow all navigation actions by default
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // Allow all navigation responses by default
        decisionHandler(.allow)
    }
}

// MARK: - WKScriptMessageHandler
extension MainViewController {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "hapticFeedback" {
            handleHapticFeedback(message: message)
        } else if message.name == "permissionBridge" {
            handlePermissionBridge(message: message)
        }
    }
}

// MARK: - ConnectivityManagerDelegate
extension MainViewController {
    func connectivityManager(_ manager: ConnectivityManager, didUpdateConnectivityStatus status: ConnectivityStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateRefreshControlForConnectivity()
        }
    }
    
    func connectivityManager(_ manager: ConnectivityManager, didUpdateGPSStatus enabled: Bool) {
        // GPS status updates can be handled here if needed
        print("📡 GPS status updated: \(enabled)")
    }
}

// MARK: - WKUIDelegate
extension MainViewController {
    // iOS 15+: Intercept media (camera/microphone) permission requests
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        print("🔐 WebView requesting media capture permission for type: \(type)")
        
        if type == .camera {
            // Move to background thread to prevent main thread blocking
            DispatchQueue.global(qos: .userInitiated).async {
                let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                print("🔐 Native camera permission status: \(cameraStatus)")
                
                DispatchQueue.main.async { [weak self] in
                    guard let _ = self else {
                        print("🔐 Self is nil, prompting for camera permission")
                        decisionHandler(.prompt)
                        return
                    }
                    
                    if cameraStatus == .authorized {
                        print("🔐 Camera permission granted natively, granting to WebView")
                        decisionHandler(.grant)
                        return
                    }
                    print("🔐 Camera permission not granted natively, prompting user")
                    decisionHandler(.prompt)
                }
            }
        } else {
            print("🔐 Non-camera media capture request, prompting user")
            decisionHandler(.prompt)
        }
    }
    
    // iOS 15+: Intercept geolocation permission requests
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        print("🔐 [WebView] 📍 Geolocation permission request (using standard behavior)")
        print("🔐 [WebView] Origin: \(origin.host)")
        
        // SIMPLIFIED: Use standard WebView permission behavior
        // No auto-granting, no custom logic, just standard browser prompts
        print("🔐 [WebView] Using standard permission prompt for user")
        decisionHandler(.prompt)
    }
    
    // Handle JavaScript alerts (including geolocation prompts)
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        print("🔐 JavaScript alert panel with message: \(message)")
        
        // Check if this is a geolocation permission request
        if message.contains("would like to use your current location") ||
           message.contains("use your precise location") ||
           message.contains("mikmik.site") {
            
            print("🔐 Detected geolocation permission request in alert")
            
            // Check location status on main thread to avoid crashes
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    print("🔐 Self is nil, completing alert")
                    completionHandler()
                    return
                }
                
                let locationStatus = CLLocationManager.authorizationStatus()
                print("🔐 Native location permission status for alert: \(locationStatus)")
                
                if locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse {
                    // Permission already granted, automatically allow
                    print("🔐 Geolocation permission already granted, automatically allowing alert")
                    completionHandler()
                    return
                }
                
                print("🔐 Showing geolocation permission alert to user")
                // For other alerts, show normal alert
                let alert = UIAlertController(title: "Zoobox", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    completionHandler()
                })
                self.present(alert, animated: true)
            }
        } else {
            print("🔐 Showing regular JavaScript alert to user")
            // For other alerts, show normal alert
            let alert = UIAlertController(title: "Zoobox", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler()
            })
            present(alert, animated: true)
        }
    }
    
    // Handle JavaScript confirm dialogs (including geolocation permission dialogs)
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        print("🔐 JavaScript confirm panel with message: \(message)")
        
        // Check if this is a geolocation permission request
        if message.contains("would like to use your current location") ||
           message.contains("use your precise location") ||
           message.contains("mikmik.site") {
            
            print("🔐 Detected geolocation permission request in confirm dialog")
            
            // Check location status on main thread to avoid crashes
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    print("🔐 Self is nil, denying confirm dialog")
                    completionHandler(false)
                    return
                }
                
                let locationStatus = CLLocationManager.authorizationStatus()
                print("🔐 Native location permission status for confirm: \(locationStatus)")
                
                if locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse {
                    // Permission already granted, automatically allow
                    print("🔐 Geolocation permission already granted, automatically allowing confirm")
                    completionHandler(true)
                    return
                }
                
                print("🔐 Showing geolocation permission confirm dialog to user")
                // For other confirms, show normal alert
                let alert = UIAlertController(title: "Zoobox", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    completionHandler(true)
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    completionHandler(false)
                })
                self.present(alert, animated: true)
            }
        } else {
            print("🔐 Showing regular JavaScript confirm dialog to user")
            // For other confirms, show normal alert
            let alert = UIAlertController(title: "Zoobox", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(true)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(false)
            })
            present(alert, animated: true)
        }
    }
}

// MARK: - Geolocation URL Scheme Handler
class GeolocationURLSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        print("🔐 Geolocation URL scheme request intercepted: \(urlSchemeTask.request.url?.absoluteString ?? "unknown")")
        
        // Check location status on main thread to avoid crashes
        DispatchQueue.main.async {
            // Check if native location permission is granted
            let locationStatus = CLLocationManager.authorizationStatus()
            
            if locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse {
                // Permission granted, return success response
                let response = HTTPURLResponse(
                    url: urlSchemeTask.request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )
                
                let responseData = "{\"status\":\"granted\",\"message\":\"Location permission already granted\"}".data(using: .utf8)
                
                urlSchemeTask.didReceive(response!)
                urlSchemeTask.didReceive(responseData!)
                urlSchemeTask.didFinish()
                
                print("🔐 Geolocation request handled - permission already granted")
            } else {
                // Permission not granted, return error response
                let response = HTTPURLResponse(
                    url: urlSchemeTask.request.url!,
                    statusCode: 403,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )
                
                let responseData = "{\"error\":\"Location permission not granted\"}".data(using: .utf8)
                
                urlSchemeTask.didReceive(response!)
                urlSchemeTask.didReceive(responseData!)
                urlSchemeTask.didFinish()
                
                print("🔐 Geolocation request handled - permission not granted")
            }
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        print("🔐 Geolocation URL scheme task stopped")
    }
}

// MARK: - Location Permission Delegate
class LocationPermissionDelegate: NSObject, CLLocationManagerDelegate {
    private let completion: (Bool) -> Void
    
    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔐 [LocationDelegate] Authorization changed to: \(status.rawValue)")
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            print("🔐 [LocationDelegate] ✅ Permission granted")
            completion(true)
        case .denied, .restricted:
            print("🔐 [LocationDelegate] ❌ Permission denied")
            completion(false)
        case .notDetermined:
            print("🔐 [LocationDelegate] 🤔 Still not determined")
            // Don't call completion yet, wait for another callback
        @unknown default:
            print("🔐 [LocationDelegate] ❓ Unknown status")
            completion(false)
        }
    }
}

// MARK: - Permission Monitor
class PermissionMonitor: NSObject {
    static let shared = PermissionMonitor()
    
    private var locationManager: CLLocationManager?
    private weak var mainViewController: MainViewController?
    
    override init() {
        super.init()
        setupLocationMonitoring()
    }
    
    func setMainViewController(_ viewController: MainViewController) {
        self.mainViewController = viewController
        print("🔐 [PermissionMonitor] Main view controller set")
    }
    
    private func setupLocationMonitoring() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        print("🔐 [PermissionMonitor] Location monitoring setup complete")
    }
}

// MARK: - Permission Monitor Delegate
extension PermissionMonitor: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔐 [PermissionMonitor] 📍 Location authorization changed to: \(status.rawValue)")
        
        // Notify main view controller of permission change
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let mainVC = self.mainViewController else {
                print("🔐 [PermissionMonitor] No main view controller to notify")
                return
            }
            
            print("🔐 [PermissionMonitor] Notifying main view controller of permission change")
            mainVC.handleLocationPermissionChange(status: status)
        }
    }
}

// MARK: - MainViewController Permission Change Handler
extension MainViewController {
    // Handle location permission changes from system
    func handleLocationPermissionChange(status: CLAuthorizationStatus) {
        print("🔐 [MainViewController] REMOVED: Permission change handling disabled by user request")
        print("🔐 [MainViewController] WebView will use standard permission behavior")
        
        // REMOVED: All permission change handling
        // - No automatic permission injection
        // - No permission status updates
        // - WebView handles permissions independently
    }
    
    
}
