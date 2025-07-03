import UIKit

class PermissionCheckViewController: UIViewController {
    
    private let permissionManager = PermissionManager.shared
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.1
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "System Check"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.textColor = .zooboxRed
        return label
    }()
    
    private let progressContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.zooboxRed.withAlphaComponent(0.1)
        view.layer.cornerRadius = 12
        return view
    }()
    
    private let progressBar: UIView = {
        let view = UIView()
        view.backgroundColor = .zooboxRed
        view.layer.cornerRadius = 10
        return view
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Checking permissions..."
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.textColor = .zooboxRed
        return label
    }()
    
    private let progressLabel: UILabel = {
        let label = UILabel()
        label.text = "0%"
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .zooboxRed
        return label
    }()
    
    private var progressWidthConstraint: NSLayoutConstraint?
    private var currentProgress: Float = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.zooboxBackground
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.async { [weak self] in
            self?.startChecking()
        }
    }
    
    private func setupUI() {
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(progressContainer)
        progressContainer.addSubview(progressBar)
        containerView.addSubview(statusLabel)
        containerView.addSubview(progressLabel)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            containerView.heightAnchor.constraint(equalToConstant: 200),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Progress container
            progressContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            progressContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            progressContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            progressContainer.heightAnchor.constraint(equalToConstant: 20),
            
            // Progress bar
            progressBar.topAnchor.constraint(equalTo: progressContainer.topAnchor, constant: 2),
            progressBar.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: -2),
            progressBar.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor, constant: 2),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Progress percentage
            progressLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            progressLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            progressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20)
        ])
        
        // Set initial progress bar width
        progressWidthConstraint = progressBar.widthAnchor.constraint(equalToConstant: 0)
        progressWidthConstraint?.isActive = true
    }
    
    private func startChecking() {
        animateProgress(to: 0.2, status: "Checking location permission...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.animateProgress(to: 0.4, status: "Checking camera permission...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.animateProgress(to: 0.6, status: "Checking notification permission...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.animateProgress(to: 0.8, status: "Verifying permissions...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.checkPermissions()
        }
    }
    
    private func animateProgress(to progress: Float, status: String) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
            self.currentProgress = progress
            self.statusLabel.text = status
            self.progressLabel.text = "\(Int(progress * 100))%"
            
            let containerWidth = self.progressContainer.frame.width - 4
            let newWidth = containerWidth * CGFloat(progress)
            self.progressWidthConstraint?.constant = newWidth
            self.view.layoutIfNeeded()
        }
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
            animateProgress(to: 1.0, status: "All permissions granted! Proceeding...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.proceedToMain()
            }
        } else {
            // Some permissions are missing, show what's needed
            let missingPermissions = notGrantedPermissions.map { $0.displayName }.joined(separator: ", ")
            animateProgress(to: 1.0, status: "Missing permissions: \(missingPermissions)")
            
            // Check if this is first run
            let isFirstRun = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if isFirstRun {
                    // First run - show welcome and onboarding
                    self.showWelcomeAndOnboarding()
                } else {
                    // Subsequent runs - show permission request for missing ones
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