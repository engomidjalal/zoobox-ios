import UIKit

class PermissionCheckViewController: UIViewController {
    
    private let permissionManager = PermissionManager.shared
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Checking Permissions..."
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .systemBlue
        indicator.startAnimating()
        return indicator
    }()
    
    private let progressLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .systemGray
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0/255, green: 119/255, blue: 182/255, alpha: 1)
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.async { [weak self] in
            self?.checkPermissions()
        }
    }
    
    private func setupUI() {
        view.addSubview(statusLabel)
        view.addSubview(activityIndicator)
        view.addSubview(progressLabel)
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 24),
            progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private func checkPermissions() {
        // Update all permission statuses first
        permissionManager.updateAllPermissionStatuses()
        
        // Get all required permissions
        let requiredPermissions: [PermissionType] = [.location, .camera, .notifications]
        
        // Check which permissions are not granted
        let notGrantedPermissions = requiredPermissions.filter { !permissionManager.isPermissionGranted(for: $0) }
        
        if notGrantedPermissions.isEmpty {
            // All permissions are granted, proceed to main
            statusLabel.text = "All Permissions Granted!\nProceeding to app..."
            progressLabel.text = "✅ Location, Camera, Notifications"
            proceedToMain()
        } else {
            // Some permissions are missing, show what's needed
            let missingPermissions = notGrantedPermissions.map { $0.displayName }.joined(separator: ", ")
            statusLabel.text = "Permissions Required"
            progressLabel.text = "Missing: \(missingPermissions)"
            
            // Check if this is first run
            let isFirstRun = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            
            if isFirstRun {
                // First run - show welcome and onboarding
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.showWelcomeAndOnboarding()
                }
            } else {
                // Subsequent runs - show permission request for missing ones
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.showPermissionRequest(for: notGrantedPermissions)
                }
            }
        }
    }
    
    private func showWelcomeAndOnboarding() {
        let welcomeVC = WelcomeViewController()
        welcomeVC.modalPresentationStyle = .fullScreen
        welcomeVC.modalTransitionStyle = .crossDissolve
        
        present(welcomeVC, animated: true) {
            print("✅ WelcomeViewController presented successfully")
        }
    }
    
    private func showPermissionRequest(for permissions: [PermissionType]) {
        // Create a simple permission request view controller
        let permissionRequestVC = SimplePermissionRequestViewController(permissions: permissions)
        permissionRequestVC.modalPresentationStyle = .fullScreen
        permissionRequestVC.modalTransitionStyle = .crossDissolve
        
        present(permissionRequestVC, animated: true) {
            print("✅ SimplePermissionRequestViewController presented successfully")
        }
    }
    
    private func proceedToMain() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // Check if we're still the top view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let topViewController = window.rootViewController?.topMostViewController(),
                  topViewController == self else {
                print("🚫 PermissionCheckViewController not top view controller - skipping navigation")
                return
            }
            
            // Go directly to main app
            let mainVC = MainViewController()
            mainVC.modalPresentationStyle = .fullScreen
            mainVC.modalTransitionStyle = .crossDissolve
            
            self.present(mainVC, animated: true) {
                print("✅ MainViewController presented successfully")
            }
        }
    }
} 