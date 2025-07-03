import UIKit

class SimplePermissionRequestViewController: UIViewController {
    
    private let permissionManager = PermissionManager.shared
    private let permissions: [PermissionType]
    private var currentPermissionIndex = 0
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Permissions Required"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxRed
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "Some permissions are required for the app to work properly."
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxRed.withAlphaComponent(0.8)
        return label
    }()
    
    private let permissionLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxRed
        return label
    }()
    
    private let reasonLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxRed.withAlphaComponent(0.7)
        return label
    }()
    
    private let enableButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Enable Permission", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .zooboxButtonPrimary
        button.setTitleColor(.zooboxTextLight, for: .normal)
        button.layer.cornerRadius = 12
        button.addTarget(self, action: #selector(enableButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Skip for Now", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.zooboxRed, for: .normal)
        button.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = .zooboxRed
        progress.trackTintColor = .zooboxRed.withAlphaComponent(0.2)
        return progress
    }()
    
    init(permissions: [PermissionType]) {
        self.permissions = permissions
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .zooboxBackground
        setupUI()
        updatePermissionDisplay()
        // Remove skip button from UI
        skipButton.removeFromSuperview()
    }
    
    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(permissionLabel)
        view.addSubview(reasonLabel)
        view.addSubview(enableButton)
        view.addSubview(skipButton)
        view.addSubview(progressView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        permissionLabel.translatesAutoresizingMaskIntoConstraints = false
        reasonLabel.translatesAutoresizingMaskIntoConstraints = false
        enableButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Progress view
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            // Permission label
            permissionLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 60),
            permissionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            permissionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            // Reason label
            reasonLabel.topAnchor.constraint(equalTo: permissionLabel.bottomAnchor, constant: 16),
            reasonLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            reasonLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            // Enable button
            enableButton.topAnchor.constraint(equalTo: reasonLabel.bottomAnchor, constant: 60),
            enableButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            enableButton.widthAnchor.constraint(equalToConstant: 200),
            enableButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Skip button
            skipButton.topAnchor.constraint(equalTo: enableButton.bottomAnchor, constant: 20),
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func updatePermissionDisplay() {
        guard currentPermissionIndex < permissions.count else {
            proceedToMain()
            return
        }
        
        let permission = permissions[currentPermissionIndex]
        let progress = Float(currentPermissionIndex + 1) / Float(permissions.count)
        
        progressView.setProgress(progress, animated: true)
        permissionLabel.text = "\(permission.displayName) Permission"
        reasonLabel.text = permission.usageDescription
        
        // Check if permission is already granted
        if permissionManager.isPermissionGranted(for: permission) {
            // Skip to next permission
            currentPermissionIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updatePermissionDisplay()
            }
        }
    }
    
    @objc private func enableButtonTapped() {
        guard currentPermissionIndex < permissions.count else { return }
        
        let permission = permissions[currentPermissionIndex]
        
        // Request permission
        permissionManager.requestPermissionDirectly(for: permission)
        
        // Update UI after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.permissionManager.isPermissionGranted(for: permission) {
                // Permission granted, move to next
                self.currentPermissionIndex += 1
                self.updatePermissionDisplay()
            } else {
                // Permission denied, show alert
                self.showPermissionDeniedAlert(for: permission)
            }
        }
    }
    
    @objc private func skipButtonTapped() {
        // Remove skip logic entirely
    }
    
    private func showPermissionDeniedAlert(for permission: PermissionType) {
        let alert = UIAlertController(
            title: "\(permission.displayName) Permission Required",
            message: "\(permission.displayName) access is needed for \(permission.usageDescription.lowercased()).\n\nYou can enable it in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }
    
    private func proceedToMain() {
        let mainVC = MainViewController()
        mainVC.modalPresentationStyle = .fullScreen
        mainVC.modalTransitionStyle = .crossDissolve
        
        present(mainVC, animated: true) {
            print("✅ MainViewController presented successfully")
        }
    }
} 