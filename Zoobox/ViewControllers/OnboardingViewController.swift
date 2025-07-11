import UIKit
import CoreLocation
import AVFoundation
import UserNotifications

class OnboardingViewController: UIViewController, PermissionManagerDelegate {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let pageControl = UIPageControl()
    private let nextButton = UIButton()
    private let skipButton = UIButton()
    private let permissionStackView = UIStackView()
    
    // MARK: - Data
    private let permissions: [PermissionItem] = [
        PermissionItem(
            type: .location,
            title: "Location Access",
            subtitle: "Enable location services to get accurate delivery tracking and nearby services",
            icon: "📍",
            color: UIColor.zooboxRed
        ),
        PermissionItem(
            type: .camera,
            title: "Camera Access",
            subtitle: "Allow camera access to scan QR codes and take photos for deliveries",
            icon: "📷",
            color: UIColor.zooboxRedLight
        ),
        PermissionItem(
            type: .notifications,
            title: "Notifications",
            subtitle: "Stay updated with delivery status, offers, and important updates",
            icon: "🔔",
            color: UIColor.zooboxRedDark
        )
    ]
    
    private var currentPage = 0
    private let permissionManager = PermissionManager.shared
    private var hasStartedAutoPermissionFlow = false
    private var autoPermissionIndex: Int = 0
    private var isAutoPermissionFlowActive = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        updateUI()
        permissionManager.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateAllPermissionStatuses()
        // Start auto permission flow if not already started
        if !hasStartedAutoPermissionFlow {
            hasStartedAutoPermissionFlow = true
            startAutoPermissionFlow()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Update permissions when returning from Settings
        permissionManager.updateAllPermissionStatuses()
        updateAllPermissionStatuses()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.zooboxBackground // Pure white background
        
        // Setup scroll view
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        view.addSubview(scrollView)
        
        // Setup content view
        scrollView.addSubview(contentView)
        
        // Setup page control
        pageControl.numberOfPages = permissions.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = UIColor.zooboxRed.withAlphaComponent(0.3)
        pageControl.currentPageIndicatorTintColor = permissions[0].color
        pageControl.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)
        view.addSubview(pageControl)
        
        // Setup buttons
        setupButtons()
        
        // Setup permission cards
        setupPermissionCards()
    }
    
    private func setupButtons() {
        // Next button
        nextButton.setTitle("Next", for: .normal)
        nextButton.setTitleColor(.zooboxTextLight, for: .normal)
        nextButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        nextButton.backgroundColor = permissions[0].color
        nextButton.layer.cornerRadius = 25
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        view.addSubview(nextButton)
    }
    
    private func setupPermissionCards() {
        permissionStackView.axis = .horizontal
        permissionStackView.distribution = .fillEqually
        permissionStackView.spacing = 0
        contentView.addSubview(permissionStackView)
        
        for (index, permission) in permissions.enumerated() {
            let cardView = createPermissionCard(for: permission, at: index)
            permissionStackView.addArrangedSubview(cardView)
        }
    }
    
    private func createPermissionCard(for permission: PermissionItem, at index: Int) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .zooboxBackground
        cardView.layer.cornerRadius = 20
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 12
        cardView.layer.shadowOpacity = 0.1
        
        // Icon container
        let iconContainer = UIView()
        iconContainer.backgroundColor = permission.color.withAlphaComponent(0.1)
        iconContainer.layer.cornerRadius = 30
        cardView.addSubview(iconContainer)
        
        let iconLabel = UILabel()
        iconLabel.text = permission.icon
        iconLabel.font = UIFont.systemFont(ofSize: 40)
        iconLabel.textAlignment = .center
        iconContainer.addSubview(iconLabel)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = permission.title
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .zooboxTextPrimary
        titleLabel.textAlignment = .center
        cardView.addSubview(titleLabel)
        
        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = permission.subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = .zooboxTextSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        cardView.addSubview(subtitleLabel)
        
        // Status indicator
        let statusView = UIView()
        statusView.backgroundColor = UIColor.zooboxTextSecondary.withAlphaComponent(0.3)
        statusView.layer.cornerRadius = 15
        cardView.addSubview(statusView)
        
        let statusLabel = UILabel()
        statusLabel.text = "Tap to enable"
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = .zooboxTextSecondary
        statusLabel.textAlignment = .center
        statusView.addSubview(statusLabel)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(permissionCardTapped(_:)))
        cardView.addGestureRecognizer(tapGesture)
        cardView.tag = index
        
        // Setup constraints
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        statusView.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Icon container
            iconContainer.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconContainer.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 60),
            iconContainer.widthAnchor.constraint(equalToConstant: 60),
            iconContainer.heightAnchor.constraint(equalToConstant: 60),
            
            // Icon
            iconLabel.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            
            // Status view
            statusView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            statusView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            statusView.widthAnchor.constraint(equalToConstant: 120),
            statusView.heightAnchor.constraint(equalToConstant: 30),
            
            // Status label
            statusLabel.centerXAnchor.constraint(equalTo: statusView.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: statusView.centerYAnchor)
        ])
        
        return cardView
    }
    
    private func setupConstraints() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        permissionStackView.translatesAutoresizingMaskIntoConstraints = false
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -20),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            // Permission stack view
            permissionStackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            permissionStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            permissionStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            permissionStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Page control
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -30),
            
            // Next button
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            nextButton.widthAnchor.constraint(equalToConstant: 200),
            nextButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Set content view width to accommodate all cards
        let cardWidth = view.bounds.width
        contentView.widthAnchor.constraint(equalToConstant: cardWidth * CGFloat(permissions.count)).isActive = true
    }
    
    // MARK: - Actions
    @objc private func nextButtonTapped() {
        // Update permission statuses to get current state
        permissionManager.updateAllPermissionStatuses()
        
        // Check if any permissions are denied and show dialog if needed
        let deniedPermissions = permissionManager.getDeniedPermissions()
        
        if !deniedPermissions.isEmpty {
            // Some permissions were denied, show the optional permissions dialog
            let deniedNames = deniedPermissions.map { $0.displayName }
            showDeniedPermissionsAlert(deniedPermissions: deniedNames)
        } else {
            // No denied permissions, proceed to main app
            proceedToMain()
        }
    }
    
    @objc private func skipButtonTapped() {
        // No-op: permission flow is now automatic
    }
    
    @objc private func pageControlChanged() {
        currentPage = pageControl.currentPage
        scrollToPage(currentPage)
    }
    
    @objc private func permissionCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let cardView = gesture.view,
              cardView.tag < permissions.count else { return }
        
        let permission = permissions[cardView.tag]
        requestPermission(for: permission, cardView: cardView)
    }
    
    // MARK: - Helper Methods
    private func scrollToPage(_ page: Int) {
        let xOffset = CGFloat(page) * view.bounds.width
        scrollView.setContentOffset(CGPoint(x: xOffset, y: 0), animated: true)
        updateUI()
    }
    
    private func updateUI() {
        pageControl.currentPage = currentPage
        pageControl.currentPageIndicatorTintColor = permissions[currentPage].color
        
        UIView.animate(withDuration: 0.3) {
            self.nextButton.backgroundColor = self.permissions[self.currentPage].color
        }
        
        if currentPage == permissions.count - 1 {
            nextButton.setTitle("Get Started", for: .normal)
        } else {
            nextButton.setTitle("Next", for: .normal)
        }
    }
    
    private func requestPermission(for permission: PermissionItem, cardView: UIView) {
        let status = permissionManager.getPermissionStatus(for: permission.type)
        
        if status == .notDetermined {
            // Request permission and handle the result
            permissionManager.requestPermissionDirectly(for: permission.type)
            
            // Update UI after a short delay to reflect the new status
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let newStatus = self.permissionManager.getPermissionStatus(for: permission.type)
                self.updatePermissionStatus(for: permission, cardView: cardView, granted: newStatus == .granted)
                
                // If permission was denied, show retry option
                if newStatus == .denied {
                    self.showPermissionDeniedAlert(for: permission, cardView: cardView)
                }
            }
        } else if status == .granted {
            updatePermissionStatus(for: permission, cardView: cardView, granted: true)
        } else {
            // Permission was previously denied, show settings alert
            showPermissionDeniedAlert(for: permission, cardView: cardView)
        }
    }
    
    private func updatePermissionStatus(for permission: PermissionItem, cardView: UIView, granted: Bool) {
        guard let statusView = cardView.subviews.last,
              let statusLabel = statusView.subviews.first as? UILabel else { return }
        
        if granted {
            UIView.animate(withDuration: 0.3) {
                statusView.backgroundColor = permission.color.withAlphaComponent(0.2)
                statusLabel.text = "✓ Enabled"
                statusLabel.textColor = permission.color
            }
        } else {
            let status = permissionManager.getPermissionStatus(for: permission.type)
            switch status {
            case .denied:
                UIView.animate(withDuration: 0.3) {
                    statusView.backgroundColor = UIColor.zooboxError.withAlphaComponent(0.2)
                    statusLabel.text = "✗ Denied"
                    statusLabel.textColor = .zooboxError
                }
            case .notDetermined:
                UIView.animate(withDuration: 0.3) {
                    statusView.backgroundColor = UIColor.zooboxWarning.withAlphaComponent(0.2)
                    statusLabel.text = "⏳ Requesting..."
                    statusLabel.textColor = .zooboxWarning
                }
            default:
                UIView.animate(withDuration: 0.3) {
                    statusView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
                    statusLabel.text = "Tap to enable"
                    statusLabel.textColor = .gray
                }
            }
        }
    }
    
    private func showDeniedPermissionsAlert(deniedPermissions: [String]) {
        let permissionList = deniedPermissions.joined(separator: ", ")
        let alert = UIAlertController(
            title: "Optional Permissions",
            message: "The following permissions were denied: \(permissionList).\n\nThese permissions help improve your experience but are not required. You can enable them later in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Continue Anyway", style: .default) { _ in
            self.proceedToMain()
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
        
        present(alert, animated: true)
    }
    
    private func showPermissionDeniedAlert(for permission: PermissionItem, cardView: UIView) {
        let alert = UIAlertController(
            title: "\(permission.title) Permission Denied",
            message: "\(permission.title) access is required for \(permission.subtitle.lowercased()).\n\nYou can enable it in Settings or try again.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
            // Reset permission status and try again
            self.permissionManager.requestPermissionDirectly(for: permission.type)
            
            // Update UI after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let newStatus = self.permissionManager.getPermissionStatus(for: permission.type)
                self.updatePermissionStatus(for: permission, cardView: cardView, granted: newStatus == .granted)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Continue Anyway", style: .cancel) { _ in
            // Allow user to continue without this permission
            print("📱 User chose to continue without \(permission.title) permission")
        })
        
        // iPad-specific popover presentation
        if UIDevice.current.isIPad {
            if let popover = alert.popoverPresentationController {
                popover.sourceView = cardView
                popover.sourceRect = cardView.bounds
                popover.permittedArrowDirections = [.up, .down]
            }
        }
        
        present(alert, animated: true)
    }
    
    private func proceedToMain() {
        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        
        // Go directly to main app - no blocking permission check
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate {
            sceneDelegate.setMainViewControllerAsRoot()
        } else {
            let mainVC = MainViewController()
            mainVC.modalPresentationStyle = .fullScreen
            mainVC.modalTransitionStyle = .crossDissolve
            present(mainVC, animated: true) {
                print("✅ MainViewController presented successfully")
            }
        }
    }
    
    private func getCurrentCardView() -> UIView? {
        guard currentPage < permissionStackView.arrangedSubviews.count else { return nil }
        return permissionStackView.arrangedSubviews[currentPage]
    }
    
    private func checkAllPermissionsAndProceed() {
        let deniedPermissions = permissionManager.getDeniedPermissions()
        let notDeterminedPermissions = permissionManager.getNotDeterminedPermissions()
        
        if !deniedPermissions.isEmpty {
            // Some permissions were denied, show options
            let deniedNames = deniedPermissions.map { $0.displayName }
            showDeniedPermissionsAlert(deniedPermissions: deniedNames)
        } else if !notDeterminedPermissions.isEmpty {
            // Some permissions not determined, request them
            requestRemainingPermissions(notDeterminedPermissions)
        } else {
            // All permissions are either granted or not determined, proceed
            proceedToMain()
        }
    }
    
    private func requestRemainingPermissions(_ permissions: [PermissionType]) {
        guard let firstPermission = permissions.first else {
            proceedToMain()
            return
        }
        
        // Find the permission item for this type
        if let permissionItem = self.permissions.first(where: { $0.type == firstPermission }),
           let cardView = getCurrentCardView() {
            requestPermission(for: permissionItem, cardView: cardView)
            
            // After requesting, check again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.checkAllPermissionsAndProceed()
            }
        } else {
            proceedToMain()
        }
    }
    
    private func updateAllPermissionStatuses() {
        for (index, permission) in permissions.enumerated() {
            if index < permissionStackView.arrangedSubviews.count {
                let cardView = permissionStackView.arrangedSubviews[index]
                let status = permissionManager.getPermissionStatus(for: permission.type)
                updatePermissionStatus(for: permission, cardView: cardView, granted: status == .granted)
            }
        }
    }
    
    private func startAutoPermissionFlow() {
        autoPermissionIndex = 0
        isAutoPermissionFlowActive = true
        requestNextPermissionIfNeeded()
    }

    private func requestNextPermissionIfNeeded() {
        guard isAutoPermissionFlowActive else { return }
        guard autoPermissionIndex < permissions.count else {
            isAutoPermissionFlowActive = false
            checkAllPermissionsAndProceed()
            return
        }
        let permission = permissions[autoPermissionIndex]
        let status = permissionManager.getPermissionStatus(for: permission.type)
        if status == .notDetermined {
            permissionManager.requestPermissionDirectly(for: permission.type)
            // Wait for delegate callback before proceeding
        } else {
            autoPermissionIndex += 1
            requestNextPermissionIfNeeded()
        }
    }

    // PermissionManagerDelegate
    func permissionManager(_ manager: PermissionManager, didUpdatePermissions permissions: [PermissionType : PermissionStatus]) {
        // Only proceed if in auto flow
        guard isAutoPermissionFlowActive else { return }
        // Check if the current permission is now determined
        let currentPermission = self.permissions[autoPermissionIndex]
        let status = permissionManager.getPermissionStatus(for: currentPermission.type)
        if status != .notDetermined {
            autoPermissionIndex += 1
            requestNextPermissionIfNeeded()
        }
        
        // Check if all permissions are now granted and auto-proceed
        checkIfAllPermissionsGrantedAndProceed()
    }
    
    private func checkIfAllPermissionsGrantedAndProceed() {
        let allGranted = permissions.allSatisfy { permission in
            permissionManager.getPermissionStatus(for: permission.type) == .granted
        }
        
        if allGranted {
            // All permissions granted, automatically proceed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkAllPermissionsAndProceed()
            }
        } else {
            // Some permissions not granted, also proceed to check and show dialog if needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkAllPermissionsAndProceed()
            }
        }
    }
    
    func permissionManager(_ manager: PermissionManager, requiresPermissionAlertFor permission: PermissionType) {
        // No-op for onboarding
    }
}

// MARK: - UIScrollViewDelegate
extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.x / scrollView.bounds.width)
        currentPage = page
        updateUI()
    }
}

// MARK: - Permission Item Model
struct PermissionItem {
    let type: PermissionType
    let title: String
    let subtitle: String
    let icon: String
    let color: UIColor
} 