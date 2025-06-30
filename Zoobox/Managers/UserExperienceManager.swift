import UIKit
import CoreHaptics
import AudioToolbox

protocol UserExperienceManagerDelegate: AnyObject {
    func userExperienceManager(_ manager: UserExperienceManager, didUpdateAccessibilitySettings settings: AccessibilitySettings)
    func userExperienceManager(_ manager: UserExperienceManager, didUpdateUserPreferences preferences: UserPreferences)
}

struct AccessibilitySettings {
    let isVoiceOverEnabled: Bool
    let isReduceMotionEnabled: Bool
    let isReduceTransparencyEnabled: Bool
    let isBoldTextEnabled: Bool
    let preferredContentSizeCategory: UIContentSizeCategory
    let isHighContrastEnabled: Bool // Placeholder, always false
}

struct UserPreferences {
    var hapticFeedbackEnabled: Bool
    var soundEffectsEnabled: Bool
    var autoRetryEnabled: Bool
    var offlineModeEnabled: Bool
    var darkModeEnabled: Bool
    var fontSize: Float
    var animationSpeed: Float
}

class UserExperienceManager: NSObject {
    static let shared = UserExperienceManager()
    
    weak var delegate: UserExperienceManagerDelegate?
    
    private var engine: CHHapticEngine?
    private let userDefaults = UserDefaults.standard
    
    private(set) var currentAccessibilitySettings: AccessibilitySettings
    private(set) var currentUserPreferences: UserPreferences
    
    override init() {
        // Initialize with default values
        self.currentAccessibilitySettings = AccessibilitySettings(
            isVoiceOverEnabled: UIAccessibility.isVoiceOverRunning,
            isReduceMotionEnabled: UIAccessibility.isReduceMotionEnabled,
            isReduceTransparencyEnabled: UIAccessibility.isReduceTransparencyEnabled,
            isBoldTextEnabled: UIAccessibility.isBoldTextEnabled,
            preferredContentSizeCategory: UIApplication.shared.preferredContentSizeCategory,
            isHighContrastEnabled: false // Placeholder
        )
        
        self.currentUserPreferences = UserPreferences(
            hapticFeedbackEnabled: true,
            soundEffectsEnabled: true,
            autoRetryEnabled: true,
            offlineModeEnabled: true,
            darkModeEnabled: false,
            fontSize: 1.0,
            animationSpeed: 1.0
        )
        
        super.init()
        
        setupHapticEngine()
        loadUserPreferences()
        setupAccessibilityObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("⚠️ Haptic feedback not supported on this device")
            return
        }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            engine?.resetHandler = { [weak self] in
                self?.setupHapticEngine()
            }
            engine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason)")
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    private func setupAccessibilityObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilitySettingsChanged),
            name: UIAccessibility.boldTextStatusDidChangeNotification,
            object: nil
        )
        
        // Removed largerTextStatusDidChangeNotification and highContrastStatusDidChangeNotification
    }
    
    // MARK: - Haptic Feedback
    
    func playHapticFeedback(_ type: HapticFeedbackType) {
        guard currentUserPreferences.hapticFeedbackEnabled else { return }
        
        switch type {
        case .light:
            playLightHaptic()
        case .medium:
            playMediumHaptic()
        case .heavy:
            playHeavyHaptic()
        case .success:
            playSuccessHaptic()
        case .warning:
            playWarningHaptic()
        case .error:
            playErrorHaptic()
        case .custom(let intensity, let sharpness):
            playCustomHaptic(intensity: intensity, sharpness: sharpness)
        }
    }
    
    private func playLightHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func playMediumHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func playHeavyHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    private func playSuccessHaptic() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    private func playWarningHaptic() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    private func playErrorHaptic() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    private func playCustomHaptic(intensity: Float, sharpness: Float) {
        guard let engine = engine else { return }
        
        let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensityParameter, sharpnessParameter],
            relativeTime: 0
        )
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play custom haptic: \(error)")
        }
    }
    
    // MARK: - Animations
    
    func animateView(_ view: UIView, animation: AnimationType, completion: (() -> Void)? = nil) {
        guard !currentAccessibilitySettings.isReduceMotionEnabled else {
            // Skip animations if reduce motion is enabled
            completion?()
            return
        }
        
        let duration = getAnimationDuration(for: animation)
        let delay = getAnimationDelay(for: animation)
        
        UIView.animate(
            withDuration: duration,
            delay: delay,
            usingSpringWithDamping: getSpringDamping(for: animation),
            initialSpringVelocity: getSpringVelocity(for: animation),
            options: getAnimationOptions(for: animation),
            animations: {
                self.applyAnimation(animation, to: view)
            },
            completion: { _ in
                completion?()
            }
        )
    }
    
    private func getAnimationDuration(for animation: AnimationType) -> TimeInterval {
        let baseDuration: TimeInterval = 0.3
        return baseDuration / Double(currentUserPreferences.animationSpeed)
    }
    
    private func getAnimationDelay(for animation: AnimationType) -> TimeInterval {
        switch animation {
        case .fadeIn, .slideIn, .scaleIn:
            return 0.1
        case .bounce, .shake:
            return 0.0
        case .custom:
            return 0.0
        }
    }
    
    private func getSpringDamping(for animation: AnimationType) -> CGFloat {
        switch animation {
        case .fadeIn, .slideIn:
            return 0.8
        case .scaleIn, .bounce:
            return 0.6
        case .shake:
            return 0.3
        case .custom:
            return 0.8
        }
    }
    
    private func getSpringVelocity(for animation: AnimationType) -> CGFloat {
        switch animation {
        case .fadeIn, .slideIn:
            return 0.5
        case .scaleIn, .bounce:
            return 0.8
        case .shake:
            return 1.0
        case .custom:
            return 0.5
        }
    }
    
    private func getAnimationOptions(for animation: AnimationType) -> UIView.AnimationOptions {
        switch animation {
        case .fadeIn, .slideIn, .scaleIn:
            return [.curveEaseInOut, .allowUserInteraction]
        case .bounce, .shake:
            return [.curveEaseInOut]
        case .custom:
            return [.curveEaseInOut]
        }
    }
    
    private func applyAnimation(_ animation: AnimationType, to view: UIView) {
        switch animation {
        case .fadeIn:
            view.alpha = 1.0
        case .slideIn:
            view.transform = .identity
        case .scaleIn:
            view.transform = .identity
        case .bounce:
            view.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIView.animate(withDuration: 0.1) {
                    view.transform = .identity
                }
            }
        case .shake:
            let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.duration = 0.6
            animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0]
            view.layer.add(animation, forKey: "shake")
        case .custom(let transform, let alpha):
            view.transform = transform
            view.alpha = alpha
        }
    }
    
    // MARK: - Accessibility
    
    @objc private func accessibilitySettingsChanged() {
        let newSettings = AccessibilitySettings(
            isVoiceOverEnabled: UIAccessibility.isVoiceOverRunning,
            isReduceMotionEnabled: UIAccessibility.isReduceMotionEnabled,
            isReduceTransparencyEnabled: UIAccessibility.isReduceTransparencyEnabled,
            isBoldTextEnabled: UIAccessibility.isBoldTextEnabled,
            preferredContentSizeCategory: UIApplication.shared.preferredContentSizeCategory,
            isHighContrastEnabled: false // Placeholder
        )
        
        currentAccessibilitySettings = newSettings
        delegate?.userExperienceManager(self, didUpdateAccessibilitySettings: newSettings)
    }
    
    func configureAccessibility(for view: UIView, label: String, hint: String? = nil, traits: UIAccessibilityTraits = []) {
        view.isAccessibilityElement = true
        view.accessibilityLabel = label
        if let hint = hint {
            view.accessibilityHint = hint
        }
        view.accessibilityTraits = traits
    }
    
    func announceAccessibilityMessage(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    // MARK: - User Preferences
    
    private func loadUserPreferences() {
        currentUserPreferences = UserPreferences(
            hapticFeedbackEnabled: userDefaults.bool(forKey: "hapticFeedbackEnabled"),
            soundEffectsEnabled: userDefaults.bool(forKey: "soundEffectsEnabled"),
            autoRetryEnabled: userDefaults.bool(forKey: "autoRetryEnabled"),
            offlineModeEnabled: userDefaults.bool(forKey: "offlineModeEnabled"),
            darkModeEnabled: userDefaults.bool(forKey: "darkModeEnabled"),
            fontSize: userDefaults.float(forKey: "fontSize"),
            animationSpeed: userDefaults.float(forKey: "animationSpeed")
        )
    }
    
    func updateUserPreferences(_ preferences: UserPreferences) {
        currentUserPreferences = preferences
        
        userDefaults.set(preferences.hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled")
        userDefaults.set(preferences.soundEffectsEnabled, forKey: "soundEffectsEnabled")
        userDefaults.set(preferences.autoRetryEnabled, forKey: "autoRetryEnabled")
        userDefaults.set(preferences.offlineModeEnabled, forKey: "offlineModeEnabled")
        userDefaults.set(preferences.darkModeEnabled, forKey: "darkModeEnabled")
        userDefaults.set(preferences.fontSize, forKey: "fontSize")
        userDefaults.set(preferences.animationSpeed, forKey: "animationSpeed")
        
        delegate?.userExperienceManager(self, didUpdateUserPreferences: preferences)
    }
    
    // MARK: - Sound Effects
    
    func playSoundEffect(_ effect: SoundEffect) {
        guard currentUserPreferences.soundEffectsEnabled else { return }
        
        // Implement sound effects here
        // You can use AudioServicesPlaySystemSound or AVAudioPlayer
        switch effect {
        case .success:
            AudioServicesPlaySystemSound(1104) // Success sound
        case .error:
            AudioServicesPlaySystemSound(1103) // Error sound
        case .warning:
            AudioServicesPlaySystemSound(1102) // Warning sound
        case .tap:
            AudioServicesPlaySystemSound(1105) // Tap sound
        }
    }
}

// MARK: - Enums

enum HapticFeedbackType {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case custom(intensity: Float, sharpness: Float)
}

enum AnimationType {
    case fadeIn
    case slideIn
    case scaleIn
    case bounce
    case shake
    case custom(transform: CGAffineTransform, alpha: CGFloat)
}

enum SoundEffect {
    case success
    case error
    case warning
    case tap
} 