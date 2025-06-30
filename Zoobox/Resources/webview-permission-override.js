// Zoobox WebView Permission Override System
// This script prevents browser permission dialogs when permissions are already granted

console.log('🔐 Zoobox Permission Override System Initializing...');

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
    
    // Override getUserMedia API (for camera)
    if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        console.log('🔐 Overriding getUserMedia API...');
        
        const originalGetUserMedia = navigator.mediaDevices.getUserMedia;
        
        navigator.mediaDevices.getUserMedia = function(constraints) {
            console.log('🔐 getUserMedia called with constraints:', constraints);
            
            // Check what permissions are needed
            const needsCamera = constraints.video;
            
            let canProceed = true;
            let missingPermissions = [];
            
            if (needsCamera && zooboxPermissions.camera !== 'granted') {
                canProceed = false;
                missingPermissions.push('camera');
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
                if (message && (message.includes('location') || message.includes('camera'))) {
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
                if (message && (message.includes('location') || message.includes('camera'))) {
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