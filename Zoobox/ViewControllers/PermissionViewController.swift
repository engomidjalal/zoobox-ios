import UIKit
import CoreLocation
import AVFoundation
import UserNotifications

class PermissionViewController: UIViewController {
    
    // MARK: - Properties
    private let permissionManager = PermissionManager.shared
    private var hasProceededToMain = false
    
    // UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = UIDevice.current.standardCornerRadius
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.1
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Welcome to Zoobox"
        label.font = UIFont.systemFont(ofSize: 28 * UIDevice.current.fontSizeMultiplier, weight: .bold)
        label.textAlignment = .center
        label.textColor = .zooboxRed
        label.numberOfLines = 0
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "These permissions are completely optional and help improve your experience. You can use the app without any of these permissions."
        label.font = UIFont.systemFont(ofSize: 16 * UIDevice.current.fontSizeMultiplier, weight: .medium)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()
    
    private let permissionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private let continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18 * UIDevice.current.fontSizeMultiplier, weight: .semibold)
        button.backgroundColor = .zooboxRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Skip for now", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16 * UIDevice.current.fontSizeMultiplier, weight: .medium)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📱 PermissionViewController viewDidLoad for device: \(UIDevice.current.deviceFamily)")
        setupUI()
        setupPermissionManager()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("📱 PermissionViewController viewDidAppear")
        
        // Check if user has already seen this screen
        if UserDefaults.standard.bool(forKey: "hasSeenPermissionScreen") {
            print("⏭️ User has already seen permission screen - proceeding to main")
            proceedToMain()
        }
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .zooboxBackground
        
        // Add subviews
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(permissionStackView)
        containerView.addSubview(continueButton)
        containerView.addSubview(skipButton)
        
        // Setup permission items
        setupPermissionItems()
        
        // Setup constraints
        setupConstraints()
    }
    
    private func setupPermissionItems() {
        let permissions = [
            ("📍", "Location (Optional)", "Show nearby services and enable deliveries - can be enabled later"),
            ("📷", "Camera (Optional)", "Scan QR codes and upload documents - can be enabled later"),
            ("🔔", "Notifications (Optional)", "Get updates about orders and deliveries - can be enabled later")
        ]
        
        for (icon, title, description) in permissions {
            let itemView = createPermissionItemView(icon: icon, title: title, description: description)
            permissionStackView.addArrangedSubview(itemView)
        }
    }
    
    private func createPermissionItemView(icon: String, title: String, description: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.systemGray6
        containerView.layer.cornerRadius = 8
        
        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        iconLabel.textAlignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16 * UIDevice.current.fontSizeMultiplier, weight: .semibold)
        titleLabel.textColor = .label
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = UIFont.systemFont(ofSize: 14 * UIDevice.current.fontSizeMultiplier)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        
        containerView.addSubview(iconLabel)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 40),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])
        
        return containerView
    }
    
    private func setupConstraints() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        permissionStackView.translatesAutoresizingMaskIntoConstraints = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: UIDevice.current.standardPadding),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -UIDevice.current.standardPadding),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            // Permission stack
            permissionStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            permissionStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            permissionStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Continue button
            continueButton.topAnchor.constraint(equalTo: permissionStackView.bottomAnchor, constant: 32),
            continueButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            continueButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Skip button
            skipButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 16),
            skipButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            skipButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    private func setupPermissionManager() {
        permissionManager.delegate = self
    }
    
    // MARK: - Actions
    
    @objc private func continueButtonTapped() {
        print("📱 Continue button tapped")
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        requestPermissions()
    }
    
    @objc private func skipButtonTapped() {
        print("📱 Skip button tapped")
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        markPermissionScreenAsSeen()
        proceedToMain()
    }
    
    // MARK: - Permission Handling
    
    private func requestPermissions() {
        print("📱 Requesting permissions...")
        
        // Request permissions one by one with proper error handling
        let permissions = [PermissionType.location, .camera, .notifications]
        var grantedCount = 0
        
        for permission in permissions {
            let currentStatus = permissionManager.getPermissionStatus(for: permission)
            
            switch currentStatus {
            case .notDetermined:
                // Request permission
                permissionManager.requestPermission(for: permission, from: self)
                grantedCount += 1
            case .granted:
                // Already granted
                grantedCount += 1
            case .denied, .restricted:
                // Permission denied, but continue
                print("📱 Permission \(permission.displayName) denied - continuing")
            }
        }
        
        // Mark screen as seen and proceed regardless of permission status
        markPermissionScreenAsSeen()
        
        // Add a small delay to allow permission dialogs to appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.proceedToMain()
        }
    }
    
    private func markPermissionScreenAsSeen() {
        UserDefaults.standard.set(true, forKey: "hasSeenPermissionScreen")
    }
    
    // MARK: - Navigation
    
    private func proceedToMain() {
        // Prevent multiple calls
        guard !hasProceededToMain else {
            print("🚫 Already proceeding to main - preventing duplicate calls")
            return
        }
        
        hasProceededToMain = true
        print("🚀 Proceeding to main app...")
        print("📱 Device: \(UIDevice.current.deviceFamily)")
        
        // Use simple, reliable navigation
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let mainVC = MainViewController()
            mainVC.modalPresentationStyle = .fullScreen
            mainVC.modalTransitionStyle = .crossDissolve
            
            // Present with completion handler to ensure proper dismissal
            self.present(mainVC, animated: true) {
                print("✅ MainViewController presented successfully")
                
                // Dismiss this view controller after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.dismiss(animated: false) {
                        print("✅ PermissionViewController dismissed successfully")
                    }
                }
            }
        }
    }
}

// MARK: - PermissionManagerDelegate

extension PermissionViewController: PermissionManagerDelegate {
    func permissionManager(_ manager: PermissionManager, didUpdatePermissions permissions: [PermissionType: PermissionStatus]) {
        print("📱 Permissions updated: \(permissions)")
        
        // Update UI if needed
        DispatchQueue.main.async {
            // You can update UI elements here if needed
            print("📱 Permission status updated in UI")
        }
    }
    
    func permissionManager(_ manager: PermissionManager, requiresPermissionAlertFor permission: PermissionType) {
        print("📱 Permission alert required for: \(permission.displayName)")
        
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "\(permission.displayName) Permission",
                message: "\(permission.displayName) access helps improve your experience but is not required. You can enable it in Settings or continue without it.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Continue Anyway", style: .default) { _ in
                // Continue without this permission
                print("📱 User chose to continue without \(permission.displayName) permission")
            })
            
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            
            // iPad-specific popover presentation
            if UIDevice.current.isIPad {
                if let popover = alert.popoverPresentationController {
                    popover.sourceView = self.view
                    popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
            }
            
            self.present(alert, animated: true)
        }
    }
}


