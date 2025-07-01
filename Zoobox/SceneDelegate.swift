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
    }
    
    // MARK: - Deep Link Handling
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url: url)
    }
    
    private func handleDeepLink(url: URL) {
        print("🔗 Handling deep link: \(url)")
        
        // Check if this is an order tracking URL
        if url.host == "mikmik.site" && url.path.contains("track_order") {
            // Extract order information from URL
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let orderId = components?.queryItems?.first { $0.name == "order_id" }?.value
            let date = components?.queryItems?.first { $0.name == "date" }?.value
            
            if let orderId = orderId, let date = date {
                print("🔗 Order tracking deep link - Order ID: \(orderId), Date: \(date)")
                // You can navigate to a specific order tracking view here
                // For now, we'll just open the URL in the web view
                openOrderTrackingURL(url: url)
            }
        }
    }
    
    private func openOrderTrackingURL(url: URL) {
        // Navigate to the main view controller and open the tracking URL
        if let mainVC = window?.rootViewController as? MainViewController {
            mainVC.loadURL(url)
        } else {
            // If main view controller isn't ready, store the URL for later
            UserDefaults.standard.set(url.absoluteString, forKey: "PendingOrderTrackingURL")
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
            // Check for pending order tracking URL
            if let pendingURLString = UserDefaults.standard.string(forKey: "PendingOrderTrackingURL"),
               let pendingURL = URL(string: pendingURLString) {
                mainVC.loadURL(pendingURL)
                UserDefaults.standard.removeObject(forKey: "PendingOrderTrackingURL")
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



