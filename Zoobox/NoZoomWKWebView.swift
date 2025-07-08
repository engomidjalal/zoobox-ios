import WebKit
import CoreLocation
import AVFoundation

class NoZoomWKWebView: WKWebView {
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        setupNoZoom()
        setupPermissionHandling()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNoZoom()
        setupPermissionHandling()
    }
    
    private func setupNoZoom() {
        // Disable link preview
        allowsLinkPreview = false
        
        // Set scroll view delegate to handle zoom events
        scrollView.delegate = self
        
        // Disable pinch gesture recognizer completely
        if let pinchGesture = scrollView.pinchGestureRecognizer {
            pinchGesture.isEnabled = false
            pinchGesture.delegate = self
        }
        
        // Set maximum and minimum zoom scale to 1.0
        scrollView.maximumZoomScale = 1.0
        scrollView.minimumZoomScale = 1.0
        scrollView.zoomScale = 1.0
        
        // Disable zoom bouncing
        scrollView.bouncesZoom = false
    }
    
    private func setupPermissionHandling() {
        // Set up permission handling to prevent dialogs when native permission is granted
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Add custom user agent to indicate this is a native app
        customUserAgent = "Zoobox/2.0 (iOS; Native App)"
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Block all pinch gestures
        if gestureRecognizer is UIPinchGestureRecognizer {
            return false
        }
        
        // Block double tap gestures
        if gestureRecognizer is UITapGestureRecognizer {
            let tapGesture = gestureRecognizer as! UITapGestureRecognizer
            if tapGesture.numberOfTapsRequired == 2 {
                return false
            }
        }
        
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
    
    override var allowsLinkPreview: Bool {
        get { return false }
        set { /* ignore */ }
    }
    
    // Override to prevent geolocation permission dialogs
    // DISABLED: JavaScript evaluation disabled to prevent EXC_BAD_ACCESS crashes
    override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        // CRITICAL: JavaScript evaluation causes EXC_BAD_ACCESS crashes
        // Completely disabled to prevent app crashes
        print("🔐 [NoZoomWKWebView] DISABLED: JavaScript evaluation disabled to prevent EXC_BAD_ACCESS crashes")
        print("🔐 [NoZoomWKWebView] DISABLED: Script would have been: \(javaScriptString.prefix(50))...")
        
        // Return error to completion handler to indicate JavaScript is disabled
        if let completionHandler = completionHandler {
            let error = NSError(domain: "ZooboxJavaScriptDisabled", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "JavaScript evaluation disabled to prevent crashes"
            ])
            completionHandler(nil, error)
        }
        
        // Do not call super.evaluateJavaScript to prevent crashes
        return
        
        /* DISABLED CODE THAT WAS CAUSING EXC_BAD_ACCESS CRASHES:
        
        // Check if this is a geolocation-related JavaScript call
        if javaScriptString.contains("geolocation") || javaScriptString.contains("getCurrentPosition") {
            // Move to background thread to prevent main thread blocking
            DispatchQueue.global(qos: .userInitiated).async {
                let locationStatus = CLLocationManager.authorizationStatus()
                
                DispatchQueue.main.async {
                    if locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse {
                        // Permission already granted, allow the JavaScript to execute
                        super.evaluateJavaScript(javaScriptString, completionHandler: completionHandler)
                    } else {
                        // Permission not granted, return error
                        if let completionHandler = completionHandler {
                            let error = NSError(domain: "GeolocationError", code: 1, userInfo: [
                                NSLocalizedDescriptionKey: "Location permission not granted"
                            ])
                            completionHandler(nil, error)
                        }
                    }
                }
            }
        } else {
            // Not geolocation-related, execute normally
            super.evaluateJavaScript(javaScriptString, completionHandler: completionHandler)
        }
        
        */
    }
}

// MARK: - UIScrollViewDelegate
extension NoZoomWKWebView: UIScrollViewDelegate {
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Force zoom scale back to 1.0 if somehow zoomed
        if scrollView.zoomScale != 1.0 {
            scrollView.setZoomScale(1.0, animated: false)
        }
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        // Return nil to disable zooming completely
        return nil
    }
}

// MARK: - UIGestureRecognizerDelegate
extension NoZoomWKWebView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Don't allow pinch gestures to work with other gestures
        if gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer {
            return false
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Make pinch gestures fail
        if gestureRecognizer is UIPinchGestureRecognizer {
            return true
        }
        return false
    }
} 