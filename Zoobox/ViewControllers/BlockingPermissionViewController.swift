import UIKit

class BlockingPermissionViewController: UIViewController {
    private let permissionManager = PermissionManager.shared
    private let requiredPermissions: [PermissionType] = [.location, .camera, .notifications]
    private var missingPermissions: [PermissionType] = []
    
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
        label.text = "You must grant all permissions to continue."
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxRed.withAlphaComponent(0.8)
        return label
    }()
    
    private let stackView = UIStackView()
    private let continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .zooboxButtonPrimary
        button.setTitleColor(.zooboxTextLight, for: .normal)
        button.layer.cornerRadius = 12
        button.isEnabled = false
        button.alpha = 0.5
        button.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
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
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        
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
            continueButton.heightAnchor.constraint(equalToConstant: 50)
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
            continueButton.isEnabled = true
            continueButton.alpha = 1.0
            descriptionLabel.text = "All permissions granted! You can continue."
        } else {
            continueButton.isEnabled = false
            continueButton.alpha = 0.5
            descriptionLabel.text = "You must grant all permissions to continue."
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
        let settingsButton = UIButton(type: .system)
        
        iconLabel.font = UIFont.systemFont(ofSize: 32)
        iconLabel.textAlignment = .center
        iconLabel.text = icon(for: permission)
        
        nameLabel.text = permission.displayName
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        nameLabel.textColor = .zooboxRed
        
        settingsButton.setTitle("Open Settings", for: .normal)
        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        settingsButton.setTitleColor(.white, for: .normal)
        settingsButton.backgroundColor = .zooboxRed
        settingsButton.layer.cornerRadius = 8
        settingsButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        
        let hStack = UIStackView(arrangedSubviews: [iconLabel, nameLabel, settingsButton])
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
    
    @objc private func openSettings(_ sender: UIButton) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    @objc private func continueButtonTapped() {
        // Only allow if all permissions are granted
        if missingPermissions.isEmpty {
            // Go to main app
            let mainVC = MainViewController()
            mainVC.modalPresentationStyle = .fullScreen
            mainVC.modalTransitionStyle = .crossDissolve
            present(mainVC, animated: true)
        }
    }
} 