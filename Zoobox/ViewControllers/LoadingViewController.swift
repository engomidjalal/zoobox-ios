import UIKit
import WebKit

protocol LoadingViewControllerDelegate: AnyObject {
    func loadingViewControllerDidTimeout(_ controller: LoadingViewController)
    func loadingViewControllerDidCancel(_ controller: LoadingViewController)
}

class LoadingViewController: UIViewController {
    
    weak var delegate: LoadingViewControllerDelegate?
    
    private var progressTimer: Timer?
    private var timeoutTimer: Timer?
    private var currentProgress: Float = 0.0
    private let maxTimeout: TimeInterval = 30.0
    
    // MARK: - UI Components
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.15
        return view
    }()
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "AppIcon") // Use your app icon
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 20
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading Zoobox"
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.textColor = .label
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Connecting to server..."
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let progressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progressTintColor = .systemBlue
        progress.trackTintColor = .systemGray5
        progress.layer.cornerRadius = 2
        progress.clipsToBounds = true
        return progress
    }()
    
    private let progressLabel: UILabel = {
        let label = UILabel()
        label.text = "0%"
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.systemRed, for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 12
        return button
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        return stack
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        startLoading()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimers()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        
        // Add blur effect
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)
        
        view.addSubview(containerView)
        containerView.addSubview(stackView)
        
        // Add subviews to stack
        stackView.addArrangedSubview(logoImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(progressView)
        stackView.addArrangedSubview(progressLabel)
        stackView.addArrangedSubview(cancelButton)
        
        // Setup constraints
        containerView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Blur view
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Container view
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            // Stack view
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32),
            
            // Logo
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            
            // Progress view
            progressView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // Cancel button
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            cancelButton.widthAnchor.constraint(equalToConstant: 120)
        ])
        
        // Initial animation
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        containerView.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
        })
    }
    
    private func setupActions() {
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func cancelButtonTapped() {
        stopTimers()
        delegate?.loadingViewControllerDidCancel(self)
    }
    
    // MARK: - Loading Management
    
    private func startLoading() {
        // Start progress simulation
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
        
        // Start timeout timer
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: maxTimeout, repeats: false) { [weak self] _ in
            self?.handleTimeout()
        }
        
        // Update subtitle based on progress
        updateSubtitle()
    }
    
    private func stopTimers() {
        progressTimer?.invalidate()
        progressTimer = nil
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
    
    private func updateProgress() {
        // Simulate realistic loading progress
        if currentProgress < 0.9 {
            let increment = Float.random(in: 0.01...0.03)
            currentProgress = min(currentProgress + increment, 0.9)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.progressView.setProgress(self.currentProgress, animated: true)
            self.progressLabel.text = "\(Int(self.currentProgress * 100))%"
            self.updateSubtitle()
        }
    }
    
    private func updateSubtitle() {
        let progress = Int(currentProgress * 100)
        
        let subtitle: String
        switch progress {
        case 0..<20:
            subtitle = "Initializing..."
        case 20..<40:
            subtitle = "Connecting to server..."
        case 40..<60:
            subtitle = "Loading content..."
        case 60..<80:
            subtitle = "Preparing interface..."
        case 80..<100:
            subtitle = "Almost ready..."
        default:
            subtitle = "Loading complete"
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.subtitleLabel.text = subtitle
        }
    }
    
    private func handleTimeout() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.subtitleLabel.text = "Connection timeout"
            self.subtitleLabel.textColor = .systemRed
            
            // Show timeout message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.delegate?.loadingViewControllerDidTimeout(self)
            }
        }
    }
    
    // MARK: - Public Methods
    
    func completeLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Complete the progress
            self.currentProgress = 1.0
            self.progressView.setProgress(1.0, animated: true)
            self.progressLabel.text = "100%"
            self.subtitleLabel.text = "Ready!"
            self.subtitleLabel.textColor = .systemGreen
            
            // Dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.dismiss(animated: true)
            }
        }
    }
    
    func updateProgress(_ progress: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentProgress = progress
            self.progressView.setProgress(progress, animated: true)
            self.progressLabel.text = "\(Int(progress * 100))%"
            self.updateSubtitle()
        }
    }
    
    func showError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.subtitleLabel.text = message
            self.subtitleLabel.textColor = .systemRed
            self.cancelButton.setTitle("Retry", for: .normal)
        }
    }
}

// MARK: - Convenience Methods

extension LoadingViewController {
    static func showLoading(from viewController: UIViewController, delegate: LoadingViewControllerDelegate? = nil) {
        let loadingVC = LoadingViewController()
        loadingVC.delegate = delegate
        loadingVC.modalPresentationStyle = .overFullScreen
        loadingVC.modalTransitionStyle = .crossDissolve
        viewController.present(loadingVC, animated: true)
    }
} 