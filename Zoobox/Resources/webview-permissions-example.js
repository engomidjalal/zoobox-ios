// Zoobox WebView Permission Usage Example
// This file shows how to use the new permission system in your web application

console.log('🔐 Zoobox Permission System Example');

// Check if ZooboxBridge is available
if (window.ZooboxBridge) {
    console.log('✅ ZooboxBridge is available');
} else {
    console.log('❌ ZooboxBridge not available');
}

// Example 1: Get current location (with permission check)
function getCurrentLocation() {
    if (window.ZooboxBridge && window.ZooboxBridge.isPermissionGranted('location')) {
        console.log('📍 Location permission granted, getting location...');
        window.ZooboxBridge.getCurrentLocation();
    } else {
        console.log('📍 Requesting location permission...');
        window.ZooboxBridge.requestPermission('location');
    }
}

// Example 2: Request camera permission for photo capture
function requestCameraAccess() {
    if (window.ZooboxBridge && window.ZooboxBridge.isPermissionGranted('camera')) {
        console.log('📷 Camera permission granted, opening camera...');
        // Your camera logic here
        openCamera();
    } else {
        console.log('📷 Requesting camera permission...');
        window.ZooboxBridge.requestPermission('camera');
    }
}

// Example 3: Check all permissions at once
function checkAllPermissions() {
    if (window.zooboxPermissions) {
        console.log('🔐 Current permissions:', window.zooboxPermissions);
        
        const permissions = {
            location: window.zooboxPermissions.location,
            camera: window.zooboxPermissions.camera,
            notifications: window.zooboxPermissions.notifications,
            microphone: window.zooboxPermissions.microphone
        };
        
        console.log('📊 Permission Summary:');
        Object.entries(permissions).forEach(([permission, status]) => {
            const statusIcon = status === 'granted' ? '✅' : status === 'denied' ? '❌' : '⚪️';
            console.log(`${statusIcon} ${permission}: ${status}`);
        });
        
        return permissions;
    } else {
        console.log('❌ No permission data available');
        return null;
    }
}

// Example 4: Listen for permission updates
function setupPermissionListener() {
    window.addEventListener('zooboxPermissionsUpdate', function(event) {
        console.log('🔐 Permissions updated:', event.detail);
        
        // Check if location was just granted
        if (event.detail.location === 'granted') {
            console.log('📍 Location permission granted! Getting location...');
            getCurrentLocation();
        }
        
        // Check if camera was just granted
        if (event.detail.camera === 'granted') {
            console.log('📷 Camera permission granted! Ready for photo capture.');
        }
        
        // Update UI based on permissions
        updateUIForPermissions(event.detail);
    });
}

// Example 5: Update UI based on permissions
function updateUIForPermissions(permissions) {
    // Example: Show/hide buttons based on permissions
    const locationButton = document.getElementById('location-btn');
    const cameraButton = document.getElementById('camera-btn');
    const notificationButton = document.getElementById('notification-btn');
    
    if (locationButton) {
        locationButton.style.display = permissions.location === 'granted' ? 'block' : 'none';
    }
    
    if (cameraButton) {
        cameraButton.style.display = permissions.camera === 'granted' ? 'block' : 'none';
    }
    
    if (notificationButton) {
        notificationButton.style.display = permissions.notifications === 'granted' ? 'block' : 'none';
    }
}

// Example 6: Request multiple permissions
function requestMultiplePermissions(permissionTypes) {
    permissionTypes.forEach(permissionType => {
        if (window.ZooboxBridge) {
            window.ZooboxBridge.requestPermission(permissionType);
        }
    });
}

// Example 7: Haptic feedback
function provideHapticFeedback(type = 'light') {
    if (window.ZooboxBridge) {
        window.ZooboxBridge.hapticFeedback(type);
    }
}

// Example 8: Complete permission flow
function initializeApp() {
    console.log('🚀 Initializing app with permission checks...');
    
    // Setup permission listener
    setupPermissionListener();
    
    // Check current permissions
    const currentPermissions = checkAllPermissions();
    
    // Request permissions if needed
    if (currentPermissions) {
        const neededPermissions = [];
        
        if (currentPermissions.location !== 'granted') {
            neededPermissions.push('location');
        }
        
        if (currentPermissions.camera !== 'granted') {
            neededPermissions.push('camera');
        }
        
        if (neededPermissions.length > 0) {
            console.log('🔐 Requesting permissions:', neededPermissions);
            requestMultiplePermissions(neededPermissions);
        }
    }
    
    // Provide haptic feedback
    provideHapticFeedback('light');
}

// Example 9: Geolocation API integration
function getLocationWithNativeAPI() {
    if (window.ZooboxBridge && window.ZooboxBridge.isPermissionGranted('location')) {
        // Use native location if permission granted
        window.ZooboxBridge.getCurrentLocation();
    } else if (navigator.geolocation) {
        // Fallback to browser geolocation
        navigator.geolocation.getCurrentPosition(
            function(position) {
                console.log('📍 Browser location:', position.coords);
            },
            function(error) {
                console.log('📍 Location error:', error.message);
                // Request native permission
                if (window.ZooboxBridge) {
                    window.ZooboxBridge.requestPermission('location');
                }
            }
        );
    } else {
        console.log('📍 Geolocation not supported');
    }
}

// Example 10: Camera API integration
function capturePhoto() {
    if (window.ZooboxBridge && window.ZooboxBridge.isPermissionGranted('camera')) {
        // Create file input for camera
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = 'image/*';
        input.capture = 'camera';
        input.onchange = function(e) {
            const file = e.target.files[0];
            if (file) {
                console.log('📷 Photo captured:', file.name);
                // Handle the photo
                handleCapturedPhoto(file);
            }
        };
        input.click();
    } else {
        console.log('📷 Requesting camera permission...');
        if (window.ZooboxBridge) {
            window.ZooboxBridge.requestPermission('camera');
        }
    }
}

// Helper functions
function openCamera() {
    console.log('📷 Opening camera...');
    // Your camera implementation
}

function handleCapturedPhoto(file) {
    console.log('📷 Processing captured photo:', file.name);
    // Your photo processing logic
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeApp);
} else {
    initializeApp();
}

// Export functions for global use
window.ZooboxPermissionExamples = {
    getCurrentLocation,
    requestCameraAccess,
    checkAllPermissions,
    setupPermissionListener,
    updateUIForPermissions,
    requestMultiplePermissions,
    provideHapticFeedback,
    initializeApp,
    getLocationWithNativeAPI,
    capturePhoto
};

console.log('🔐 Zoobox Permission Examples loaded'); 