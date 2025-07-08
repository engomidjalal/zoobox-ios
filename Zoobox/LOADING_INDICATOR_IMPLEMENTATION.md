# Loading Indicator Implementation

## Overview

This document describes the comprehensive loading indicator system implemented across the Zoobox iOS app to prevent white screens and provide visual feedback during all loading states and transitions.

## Architecture

### LoadingIndicatorManager
- **Location**: `Zoobox/Managers/LoadingIndicatorManager.swift`
- **Purpose**: Centralized loading indicator management following Apple's design guidelines
- **Features**:
  - Red color indicator (following Apple guidelines)
  - Optional message display
  - Smooth fade in/out animations
  - Prevents multiple indicators from showing simultaneously
  - Thread-safe operations

### UIViewController Extension
- **Convenience Methods**:
  - `showLoadingIndicator(message: String?)`
  - `hideLoadingIndicator()`
  - `showLoadingIndicatorWithCompletion(message: String?, completion: @escaping () -> Void)`

## Implementation Locations

### 1. App Startup Flow

#### SplashViewController
- **When**: `viewDidLoad()`
- **Message**: "Starting Zoobox..."
- **Purpose**: Prevents white screen during app initialization
- **Hidden**: Before navigation to ConnectivityViewController

#### ConnectivityViewController
- **When**: `viewDidAppear()`
- **Message**: "Checking connectivity..."
- **Purpose**: Shows during connectivity checks
- **Hidden**: Before navigation to PermissionCheckViewController

#### PermissionCheckViewController
- **When**: `viewDidAppear()`
- **Message**: "Checking permissions..."
- **Purpose**: Shows during permission verification
- **Hidden**: Before navigation to WelcomeViewController or MainViewController

### 2. Onboarding Flow

#### WelcomeViewController
- **When**: Button tap to start onboarding
- **Message**: "Preparing onboarding..."
- **Purpose**: Smooth transition to onboarding
- **Hidden**: After OnboardingViewController is presented

#### OnboardingViewController
- **When**: Proceeding to main app
- **Message**: "Setting up your account..."
- **Purpose**: Shows during account setup transition
- **Hidden**: After MainViewController is set as root

### 3. Main App

#### MainViewController
- **When**: Initial webview load and retry attempts
- **Message**: "Loading Zoobox..." (initial) or "Retrying..." (retries)
- **Purpose**: Shows during webview loading states
- **Hidden**: When webview finishes loading or encounters errors

### 4. WebView Navigation Delegate
- **Integration**: Uses shared LoadingIndicatorManager
- **States**:
  - Shows during `didStartProvisionalNavigation`
  - Hides on `didFinish` (success)
  - Hides on `didFail` and `didFailProvisionalNavigation` (errors)

## Key Features

### 1. White Screen Prevention
- Loading indicators are shown immediately in `viewDidLoad()` or `viewDidAppear()`
- No white screens during app startup, transitions, or loading states

### 2. Apple Design Guidelines Compliance
- Red color indicator (`UIColor.systemRed`)
- Large style (`UIActivityIndicatorView(style: .large)`)
- Proper contrast and accessibility

### 3. Smooth Transitions
- Fade in/out animations (0.3 seconds)
- Proper timing with navigation transitions
- Prevents jarring visual changes

### 4. State Management
- Prevents multiple indicators from showing simultaneously
- Proper cleanup and memory management
- Thread-safe operations on main queue

### 5. User Experience
- Contextual messages for different activities
- Consistent behavior across all view controllers
- No blocking UI during loading states

## Usage Examples

### Basic Usage
```swift
// Show loading indicator
showLoadingIndicator(message: "Loading...")

// Hide loading indicator
hideLoadingIndicator()
```

### With Completion Handler
```swift
showLoadingIndicatorWithCompletion(message: "Preparing...") {
    // Perform async operation
    performAsyncOperation { result in
        DispatchQueue.main.async {
            self.hideLoadingIndicator()
            // Handle result
        }
    }
}
```

### During Navigation
```swift
// Show before navigation
showLoadingIndicator(message: "Transitioning...")

// Navigate
let nextVC = NextViewController()
present(nextVC, animated: true) {
    // Hide after navigation completes
    self.hideLoadingIndicator()
}
```

## Error Handling

### WebView Errors
- Loading indicator is hidden when webview encounters errors
- Error alerts are shown with retry options
- No loading indicator conflicts with error states

### Network Errors
- Loading indicator is hidden during connectivity checks
- Proper fallback to error states
- Consistent user experience

## Performance Considerations

### Memory Management
- Loading indicators are properly deallocated
- No memory leaks from retained references
- Efficient constraint management

### Animation Performance
- Smooth 60fps animations
- No blocking operations during animations
- Proper use of main queue for UI updates

## Testing

### Manual Testing Checklist
- [ ] App startup shows loading indicator
- [ ] Connectivity check shows loading indicator
- [ ] Permission check shows loading indicator
- [ ] Onboarding transitions show loading indicator
- [ ] Webview loading shows loading indicator
- [ ] Retry attempts show loading indicator
- [ ] No white screens during any transition
- [ ] Loading indicators hide properly on completion
- [ ] Loading indicators hide properly on errors

### Edge Cases
- [ ] Rapid navigation between screens
- [ ] Network connectivity changes during loading
- [ ] App backgrounding during loading
- [ ] Memory pressure scenarios
- [ ] Orientation changes during loading

## Future Enhancements

### Potential Improvements
1. **Custom Loading Animations**: Brand-specific loading animations
2. **Progress Indicators**: For operations with known progress
3. **Skeleton Screens**: For content loading states
4. **Offline States**: Different indicators for offline scenarios
5. **Accessibility**: Enhanced VoiceOver support

### Configuration Options
1. **Custom Colors**: Brand color support
2. **Custom Messages**: Localized message support
3. **Custom Timing**: Configurable animation durations
4. **Custom Styles**: Different indicator styles per context

## Conclusion

The loading indicator implementation provides a comprehensive solution for preventing white screens and improving user experience across the entire Zoobox iOS app. The centralized approach ensures consistency, maintainability, and adherence to Apple's design guidelines while providing smooth, professional loading states for all user interactions. 