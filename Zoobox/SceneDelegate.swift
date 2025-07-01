import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)

        // Start with SplashViewController to ensure proper permission flow
        let splashViewController = SplashViewController()
        window?.rootViewController = splashViewController
        window?.makeKeyAndVisible()
        
        // Handle any deep links that launched the app
        if let urlContext = connectionOptions.urlContexts.first {
            handleDeepLink(url: urlContext.url)
        }
        
        // Handle notification launch options
        if let notificationResponse = connectionOptions.notificationResponse {
            handleNotificationLaunch(notificationResponse: notificationResponse)
        }
    }
    
    // MARK: - Deep Link Handling
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url: url)
    }
    
    private func handleDeepLink(url: URL) {
        print("🔗 Handling deep link: \(url)")
        
        // Check if this is an order tracking URL (from FCM notifications)
        if url.host == "mikmik.site" && url.path.contains("track_order") {
            // Extract order information from URL
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let orderId = components?.queryItems?.first { $0.name == "order_id" }?.value
            let date = components?.queryItems?.first { $0.name == "date" }?.value
            
            if let orderId = orderId, let date = date {
                print("🔗 Order tracking deep link from FCM - Order ID: \(orderId), Date: \(date)")
                // Open the tracking URL in the web view
                openOrderTrackingURL(url: url)
            }
        }
    }
    
    private func openOrderTrackingURL(url: URL) {
        // Navigate to the main view controller and open the tracking URL (from FCM)
        if let mainVC = window?.rootViewController as? MainViewController {
            mainVC.loadURL(url)
        } else {
            // If main view controller isn't ready, store the URL for later
            UserDefaults.standard.set(url.absoluteString, forKey: "PendingOrderTrackingURL")
        }
    }
    
    private func handleNotificationLaunch(notificationResponse: UNNotificationResponse) {
        print("🔔 App launched from notification: \(notificationResponse.notification.request.identifier)")
        
        // Extract notification data
        let userInfo = notificationResponse.notification.request.content.userInfo
        print("🔔 Notification userInfo: \(userInfo)")
        
        // Handle FCM notification deep linking
        handleFCMNotificationDeepLink(userInfo: userInfo)
    }
    
    private func handleFCMNotificationDeepLink(userInfo: [AnyHashable: Any]) {
        print("🔗 Processing FCM notification for deep linking (app launch)")
        
        // Extract order_type and order_id from notification data
        guard let orderType = userInfo["order_type"] as? String,
              let orderId = userInfo["order_id"] as? String else {
            print("🔗 Missing order_type or order_id in notification data")
            return
        }
        
        print("🔗 Order Type: \(orderType), Order ID: \(orderId)")
        
        // Construct deep link URL based on order type
        var deepLinkURL: URL?
        
        switch orderType.lowercased() {
        case "food":
            // Food order tracking URL
            let urlString = "https://mikmik.site/track_order.php?order_id=\(orderId)"
            deepLinkURL = URL(string: urlString)
            print("🔗 Food order deep link: \(urlString)")
            
        case "d2d":
            // D2D order tracking URL
            let urlString = "https://mikmik.site/d2d/track_d2d.php?order_id=\(orderId)"
            deepLinkURL = URL(string: urlString)
            print("🔗 D2D order deep link: \(urlString)")
            
        default:
            print("🔗 Unknown order type: \(orderType)")
            return
        }
        
        // Store the URL to be opened when main view controller is ready
        if let url = deepLinkURL {
            UserDefaults.standard.set(url.absoluteString, forKey: "PendingFCMDeepLinkURL")
            print("🔗 Stored pending FCM deep link URL: \(url)")
        }
    }
    
    // MARK: - Navigation Helper
    func setMainViewControllerAsRoot() {
        let mainVC = MainViewController()
        mainVC.modalPresentationStyle = .fullScreen
        mainVC.modalTransitionStyle = .crossDissolve
        
        // Set as root view controller with animation
        UIView.transition(with: window!, duration: 0.5, options: .transitionCrossDissolve, animations: {
            self.window?.rootViewController = mainVC
        }, completion: { _ in
            // Check for pending order tracking URL (from FCM)
            if let pendingURLString = UserDefaults.standard.string(forKey: "PendingOrderTrackingURL"),
               let pendingURL = URL(string: pendingURLString) {
                mainVC.loadURL(pendingURL)
                UserDefaults.standard.removeObject(forKey: "PendingOrderTrackingURL")
            }
            
            // Check for pending FCM deep link URL
            if let pendingFCMURLString = UserDefaults.standard.string(forKey: "PendingFCMDeepLinkURL"),
               let pendingFCMURL = URL(string: pendingFCMURLString) {
                print("🔗 Loading pending FCM deep link URL: \(pendingFCMURL)")
                mainVC.loadURL(pendingFCMURL)
                UserDefaults.standard.removeObject(forKey: "PendingFCMDeepLinkURL")
            }
        })
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        print("🔄 Scene disconnected")
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        print("🔄 Scene became active")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        print("🔄 Scene will resign active")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        print("🔄 Scene will enter foreground")
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        print("🔄 Scene did enter background")
    }
}



