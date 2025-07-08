import UIKit

extension UIDevice {
    
    /// Returns true if the current device is an iPad
    var isIPad: Bool {
        return userInterfaceIdiom == .pad
    }
    
    /// Returns true if the current device is an iPhone
    var isIPhone: Bool {
        return userInterfaceIdiom == .phone
    }
    
    /// Returns the device family as a string for debugging
    var deviceFamily: String {
        switch userInterfaceIdiom {
        case .phone:
            return "iPhone"
        case .pad:
            return "iPad"
        case .tv:
            return "Apple TV"
        case .carPlay:
            return "CarPlay"
        case .mac:
            return "Mac"
        case .vision:
            return "Vision"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Returns the current orientation as a string
    var orientationString: String {
        switch UIDevice.current.orientation {
        case .portrait:
            return "Portrait"
        case .portraitUpsideDown:
            return "Portrait Upside Down"
        case .landscapeLeft:
            return "Landscape Left"
        case .landscapeRight:
            return "Landscape Right"
        case .faceUp:
            return "Face Up"
        case .faceDown:
            return "Face Down"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Returns device-specific constraint multiplier for iPad vs iPhone
    var constraintMultiplier: CGFloat {
        return isIPad ? 0.3 : 0.1 // iPad gets smaller margins (30% vs 10%)
    }
    
    /// Returns device-specific padding for iPad vs iPhone
    var standardPadding: CGFloat {
        return isIPad ? 60.0 : 40.0
    }
    
    /// Returns device-specific corner radius for iPad vs iPhone
    var standardCornerRadius: CGFloat {
        return isIPad ? 24.0 : 16.0
    }
    
    /// Returns device-specific font size multiplier
    var fontSizeMultiplier: CGFloat {
        return isIPad ? 1.2 : 1.0
    }
    
    /// Returns device-specific timeout values (iPad may need longer timeouts)
    var webViewTimeout: TimeInterval {
        return isIPad ? 30.0 : 20.0
    }
    
    /// Returns device-specific retry count (iPad may need more retries)
    var maxRetryCount: Int {
        return isIPad ? 5 : 3
    }
    
    /// Returns device-specific loading delay (iPad may need longer delays)
    var loadingDelay: TimeInterval {
        return isIPad ? 2.0 : 1.0
    }
    
    /// Returns device-specific debug information
    var debugInfo: String {
        return """
        Device: \(deviceFamily)
        Model: \(model)
        System: \(systemName) \(systemVersion)
        Orientation: \(orientationString)
        Screen: \(UIScreen.main.bounds.size)
        Scale: \(UIScreen.main.scale)
        """
    }
} 