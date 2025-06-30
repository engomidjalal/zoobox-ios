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
    }
    
    // MARK: - Navigation Helper
    func setMainViewControllerAsRoot() {
        let mainVC = MainViewController()
        mainVC.modalPresentationStyle = .fullScreen
        mainVC.modalTransitionStyle = .crossDissolve
        
        // Set as root view controller with animation
        UIView.transition(with: window!, duration: 0.5, options: .transitionCrossDissolve, animations: {
            self.window?.rootViewController = mainVC
        }, completion: nil)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }
}



