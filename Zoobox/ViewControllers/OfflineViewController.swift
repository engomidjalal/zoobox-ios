import UIKit
import WebKit

protocol OfflineViewControllerDelegate: AnyObject {
    func offlineViewControllerDidTapRetry(_ controller: OfflineViewController)
    func offlineViewControllerDidTapSettings(_ controller: OfflineViewController)
    func offlineViewControllerDidTapOfflineMode(_ controller: OfflineViewController)
    func offlineViewControllerDidTapClearCache(_ controller: OfflineViewController)
}

class OfflineViewController: UIViewController {
    
    weak var delegate: OfflineViewControllerDelegate?
    private var hasCachedContent: Bool = false
    
    // MARK: - UI Components
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    private let offlineIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "wifi.slash")
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .zooboxError
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "You're Offline"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxTextPrimary
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Don't worry! You can still access some features and cached content while offline."
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxTextSecondary
        return label
    }()
    
    private let statusCard: UIView = {
        let view = UIView()
        view.backgroundColor = .zooboxButtonSecondary
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.zooboxTextSecondary.withAlphaComponent(0.2).cgColor
        return view
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .zooboxTextSecondary
        label.numberOfLines = 0
        return label
    }()
    
    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Try Again", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .zooboxButtonPrimary
        button.setTitleColor(.zooboxTextLight, for: .normal)
        button.layer.cornerRadius = 12
        return button
    }()
    
    private let settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Check Settings", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .zooboxButtonSecondary
        button.setTitleColor(.zooboxTextPrimary, for: .normal)
        button.layer.cornerRadius = 12
        return button
    }()
    
    private let offlineModeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Offline Mode", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .zooboxSuccess
        button.setTitleColor(.zooboxTextLight, for: .normal)
        button.layer.cornerRadius = 12
        button.isHidden = true
        return button
    }()
    
    private let cacheInfoView: UIView = {
        let view = UIView()
        view.backgroundColor = .zooboxBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.zooboxTextSecondary.withAlphaComponent(0.3).cgColor
        view.isHidden = true
        return view
    }()
    
    private let cacheTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Cached Content"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .zooboxTextPrimary
        return label
    }()
    
    private let cacheDescriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "You have cached content available for offline viewing"
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .zooboxTextSecondary
        label.numberOfLines = 0
        return label
    }()
    
    private let clearCacheButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Clear Cache", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(.zooboxError, for: .normal)
        return button
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .center
        return stack
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        checkCachedContent()
        updateStatus()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateStatus()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .zooboxBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        // Add subviews to stack
        stackView.addArrangedSubview(offlineIconView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(statusCard)
        stackView.addArrangedSubview(retryButton)
        stackView.addArrangedSubview(settingsButton)
        stackView.addArrangedSubview(offlineModeButton)
        stackView.addArrangedSubview(cacheInfoView)
        
        // Setup cache info view
        cacheInfoView.addSubview(cacheTitleLabel)
        cacheInfoView.addSubview(cacheDescriptionLabel)
        cacheInfoView.addSubview(clearCacheButton)
        
        // Setup constraints
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        statusCard.translatesAutoresizingMaskIntoConstraints = false
        cacheInfoView.translatesAutoresizingMaskIntoConstraints = false
        cacheTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cacheDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        clearCacheButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Stack view
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            
            // Icon
            offlineIconView.heightAnchor.constraint(equalToConstant: 100),
            offlineIconView.widthAnchor.constraint(equalToConstant: 100),
            
            // Status card
            statusCard.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            statusCard.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            statusCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            // Buttons
            retryButton.heightAnchor.constraint(equalToConstant: 50),
            retryButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            
            settingsButton.heightAnchor.constraint(equalToConstant: 50),
            settingsButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            
            offlineModeButton.heightAnchor.constraint(equalToConstant: 50),
            offlineModeButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            
            // Cache info view
            cacheInfoView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            cacheInfoView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            cacheInfoView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            // Cache info subviews
            cacheTitleLabel.topAnchor.constraint(equalTo: cacheInfoView.topAnchor, constant: 16),
            cacheTitleLabel.leadingAnchor.constraint(equalTo: cacheInfoView.leadingAnchor, constant: 16),
            cacheTitleLabel.trailingAnchor.constraint(equalTo: cacheInfoView.trailingAnchor, constant: -16),
            
            cacheDescriptionLabel.topAnchor.constraint(equalTo: cacheTitleLabel.bottomAnchor, constant: 8),
            cacheDescriptionLabel.leadingAnchor.constraint(equalTo: cacheInfoView.leadingAnchor, constant: 16),
            cacheDescriptionLabel.trailingAnchor.constraint(equalTo: cacheInfoView.trailingAnchor, constant: -16),
            
            clearCacheButton.topAnchor.constraint(equalTo: cacheDescriptionLabel.bottomAnchor, constant: 12),
            clearCacheButton.leadingAnchor.constraint(equalTo: cacheInfoView.leadingAnchor, constant: 16),
            clearCacheButton.bottomAnchor.constraint(equalTo: cacheInfoView.bottomAnchor, constant: -16)
        ])
        
        // Add status label to status card
        statusCard.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupActions() {
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        offlineModeButton.addTarget(self, action: #selector(offlineModeButtonTapped), for: .touchUpInside)
        clearCacheButton.addTarget(self, action: #selector(clearCacheButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func retryButtonTapped() {
        animateButtonTap(retryButton) {
            self.delegate?.offlineViewControllerDidTapRetry(self)
        }
    }
    
    @objc private func settingsButtonTapped() {
        animateButtonTap(settingsButton) {
            self.delegate?.offlineViewControllerDidTapSettings(self)
        }
    }
    
    @objc private func offlineModeButtonTapped() {
        animateButtonTap(offlineModeButton) {
            self.delegate?.offlineViewControllerDidTapOfflineMode(self)
        }
    }
    
    @objc private func clearCacheButtonTapped() {
        let alert = UIAlertController(title: "Clear Cache", message: "This will remove all cached content. Are you sure?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            self.delegate?.offlineViewControllerDidTapClearCache(self)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func animateButtonTap(_ button: UIButton, completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = .identity
            } completion: { _ in
                completion()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkCachedContent() {
        // Check if there's cached content available
        let dataStore = WKWebsiteDataStore.default()
        dataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            DispatchQueue.main.async {
                self?.hasCachedContent = !cookies.isEmpty
                self?.updateCacheInfoView()
            }
        }
    }
    
    private func updateStatus() {
        let connectivityManager = ConnectivityManager.shared
        let status = connectivityManager.currentConnectivityStatus
        
        switch status {
        case .connected:
            statusLabel.text = "✅ Internet connection detected"
            statusLabel.textColor = .zooboxSuccess
        case .disconnected:
            statusLabel.text = "❌ No internet connection available"
            statusLabel.textColor = .zooboxError
        case .checking:
            statusLabel.text = "🔄 Checking connection..."
            statusLabel.textColor = .zooboxWarning
        case .unknown:
            statusLabel.text = "❓ Connection status unknown"
            statusLabel.textColor = .systemGray
        }
    }
    
    private func updateCacheInfoView() {
        cacheInfoView.isHidden = !hasCachedContent
        offlineModeButton.isHidden = !hasCachedContent
        
        if hasCachedContent {
            cacheDescriptionLabel.text = "You have cached content available for offline viewing"
        }
    }
    
    // MARK: - Public Methods
    
    func updateConnectivityStatus(_ status: ConnectivityStatus) {
        DispatchQueue.main.async {
            self.updateStatus()
        }
    }
    
    func showCachedContent() {
        hasCachedContent = true
        updateCacheInfoView()
    }
    
    func hideCachedContent() {
        hasCachedContent = false
        updateCacheInfoView()
    }
} 