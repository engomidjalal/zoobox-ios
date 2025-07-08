import UIKit

class BlockingPermissionViewController: UIViewController {
    private let permissionManager = PermissionManager.shared
    private let requiredPermissions: [PermissionType] = [.location, .camera, .notifications]
    private var missingPermissions: [PermissionType] = []
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Optional Permissions"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxRed
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "These permissions help improve your experience, but are not required to use the app."
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxRed.withAlphaComponent(0.8)
        return label
    }()
    
    private let stackView = UIStackView()
    private let continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue to App", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .zooboxButtonPrimary
        button.setTitleColor(.zooboxTextLight, for: .normal)
        button.layer.cornerRadius = 12
        button.isEnabled = true
        button.alpha = 1.0
        button.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Skip Permissions", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.zooboxRed, for: .normal)
        button.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .zooboxBackground
        setupUI()
        checkPermissionsAndUpdateUI()
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(stackView)
        view.addSubview(continueButton)
        view.addSubview(skipButton)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .fill
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            stackView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 40),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            continueButton.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 40),
            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueButton.widthAnchor.constraint(equalToConstant: 200),
            continueButton.heightAnchor.constraint(equalToConstant: 50),
            
            skipButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 20),
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    @objc private func appDidBecomeActive() {
        checkPermissionsAndUpdateUI()
    }
    
    private func checkPermissionsAndUpdateUI() {
        permissionManager.updateAllPermissionStatuses()
        missingPermissions = requiredPermissions.filter { !permissionManager.isPermissionGranted(for: $0) }
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if missingPermissions.isEmpty {
            descriptionLabel.text = "All permissions granted! You're all set."
        } else {
            descriptionLabel.text = "These permissions help improve your experience, but are not required to use the app."
            for permission in missingPermissions {
                let row = permissionRow(for: permission)
                stackView.addArrangedSubview(row)
            }
        }
    }
    
    private func permissionRow(for permission: PermissionType) -> UIView {
        let container = UIView()
        let iconLabel = UILabel()
        let nameLabel = UILabel()
        let enableButton = UIButton(type: .system)
        
        iconLabel.font = UIFont.systemFont(ofSize: 32)
        iconLabel.textAlignment = .center
        iconLabel.text = icon(for: permission)
        
        nameLabel.text = permission.displayName
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        nameLabel.textColor = .zooboxRed
        
        enableButton.setTitle("Enable", for: .normal)
        enableButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        enableButton.setTitleColor(.white, for: .normal)
        enableButton.backgroundColor = .zooboxRed
        enableButton.layer.cornerRadius = 8
        enableButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        enableButton.addTarget(self, action: #selector(enablePermission(_:)), for: .touchUpInside)
        enableButton.tag = permission.hashValue
        
        let hStack = UIStackView(arrangedSubviews: [iconLabel, nameLabel, enableButton])
        hStack.axis = .horizontal
        hStack.spacing = 16
        hStack.alignment = .center
        hStack.distribution = .fillProportionally
        
        container.addSubview(hStack)
        hStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: container.topAnchor),
            hStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }
    
    private func icon(for permission: PermissionType) -> String {
        switch permission {
        case .location: return "📍"
        case .camera: return "📷"
        case .notifications: return "🔔"
        default: return "❗️"
        }
    }
    
    @objc private func enablePermission(_ sender: UIButton) {
        // Find the permission type based on the button tag
        let permissionType = requiredPermissions.first { $0.hashValue == sender.tag }
        guard let permission = permissionType else { return }
        
        // Request permission
        permissionManager.requestPermissionDirectly(for: permission)
        
        // Update UI after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkPermissionsAndUpdateUI()
        }
    }
    
    @objc private func skipButtonTapped() {
        proceedToMain()
    }
    
    @objc private func continueButtonTapped() {
        proceedToMain()
    }
    
    private func proceedToMain() {
        // Go to main app regardless of permission status
        let mainVC = MainViewController()
        mainVC.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        mainVC.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        present(mainVC, animated: true)
    }
} 