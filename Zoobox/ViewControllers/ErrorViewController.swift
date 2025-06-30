import UIKit
import WebKit
import Foundation

enum ErrorType {
    case noInternet
    case httpError(Int)
    case webError(String)
    case timeout
    case serverError
    case unknown
    
    var title: String {
        switch self {
        case .noInternet:
            return "No Internet Connection"
        case .httpError(let code):
            return "Connection Error (\(code))"
        case .webError:
            return "Web Error"
        case .timeout:
            return "Connection Timeout"
        case .serverError:
            return "Server Error"
        case .unknown:
            return "Something Went Wrong"
        }
    }
    
    var message: String {
        switch self {
        case .noInternet:
            return "Please check your Wi-Fi or cellular data connection and try again."
        case .httpError(let code):
            switch code {
            case 404:
                return "The page you're looking for doesn't exist."
            case 403:
                return "Access denied. You don't have permission to view this content."
            case 500...599:
                return "Server error. Please try again later."
            default:
                return "Unable to load the page. Please try again."
            }
        case .webError(let message):
            return message
        case .timeout:
            return "The connection timed out. Please check your internet connection and try again."
        case .serverError:
            return "The server is currently unavailable. Please try again later."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
    
    var iconName: String {
        switch self {
        case .noInternet:
            return "wifi.slash"
        case .httpError, .webError, .serverError:
            return "exclamationmark.triangle"
        case .timeout:
            return "clock"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    var primaryActionTitle: String {
        switch self {
        case .noInternet:
            return "Check Settings"
        case .httpError, .webError, .timeout, .serverError, .unknown:
            return "Try Again"
        }
    }
    
    var secondaryActionTitle: String {
        switch self {
        case .noInternet:
            return "Try Again"
        case .httpError, .webError, .timeout, .serverError, .unknown:
            return "Check Connection"
        }
    }
}

protocol ErrorViewControllerDelegate: AnyObject {
    func errorViewControllerDidTapRetry(_ controller: ErrorViewController)
    func errorViewControllerDidTapSettings(_ controller: ErrorViewController)
    func errorViewControllerDidTapCheckConnection(_ controller: ErrorViewController)
}

class ErrorViewController: UIViewController {
    
    weak var delegate: ErrorViewControllerDelegate?
    private let errorType: ErrorType
    
    // MARK: - UI Components
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .zooboxBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .zooboxError
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxTextPrimary
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxTextSecondary
        return label
    }()
    
    private let primaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .zooboxButtonPrimary
        button.setTitleColor(.zooboxTextLight, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 12
        button.layer.shadowColor = UIColor.zooboxRed.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.3
        return button
    }()
    
    private let secondaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .zooboxButtonSecondary
        button.setTitleColor(.zooboxTextPrimary, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
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
    
    // MARK: - Initialization
    
    init(errorType: ErrorType) {
        self.errorType = errorType
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureForErrorType()
        setupActions()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.zooboxBackground.withAlphaComponent(0.95)
        
        // Add blur effect
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)
        
        view.addSubview(containerView)
        containerView.addSubview(stackView)
        
        // Add subviews to stack
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        stackView.addArrangedSubview(primaryButton)
        stackView.addArrangedSubview(secondaryButton)
        
        // Setup constraints
        containerView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Blur view
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Container view
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            // Stack view
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -32),
            
            // Icon
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            
            // Buttons
            primaryButton.heightAnchor.constraint(equalToConstant: 50),
            primaryButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            
            secondaryButton.heightAnchor.constraint(equalToConstant: 50),
            secondaryButton.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
    }
    
    private func configureForErrorType() {
        titleLabel.text = errorType.title
        messageLabel.text = errorType.message
        
        // Configure icon
        if let icon = UIImage(systemName: errorType.iconName) {
            iconImageView.image = icon
        }
        
        // Configure buttons
        primaryButton.setTitle(errorType.primaryActionTitle, for: .normal)
        secondaryButton.setTitle(errorType.secondaryActionTitle, for: .normal)
        
        // Add animation
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        containerView.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
            self.containerView.transform = .identity
            self.containerView.alpha = 1
        })
    }
    
    private func setupActions() {
        primaryButton.addTarget(self, action: #selector(primaryButtonTapped), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(secondaryButtonTapped), for: .touchUpInside)
        
        // Add tap gesture to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    
    @objc private func primaryButtonTapped() {
        animateButtonTap(primaryButton) {
            switch self.errorType {
            case .noInternet:
                self.delegate?.errorViewControllerDidTapSettings(self)
            case .httpError, .webError, .timeout, .serverError, .unknown:
                self.delegate?.errorViewControllerDidTapRetry(self)
            }
        }
    }
    
    @objc private func secondaryButtonTapped() {
        animateButtonTap(secondaryButton) {
            switch self.errorType {
            case .noInternet:
                self.delegate?.errorViewControllerDidTapRetry(self)
            case .httpError, .webError, .timeout, .serverError, .unknown:
                self.delegate?.errorViewControllerDidTapCheckConnection(self)
            }
        }
    }
    
    @objc private func backgroundTapped() {
        // Don't dismiss on background tap for critical errors
        // Only allow dismissal for non-critical errors
        switch errorType {
        case .noInternet, .serverError:
            return
        default:
            dismiss(animated: true)
        }
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
    
    // MARK: - Public Methods
    
    func updateErrorType(_ newErrorType: ErrorType) {
        // Animate out
        UIView.animate(withDuration: 0.2, animations: {
            self.containerView.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            // Update content
            self.titleLabel.text = newErrorType.title
            self.messageLabel.text = newErrorType.message
            
            if let icon = UIImage(systemName: newErrorType.iconName) {
                self.iconImageView.image = icon
            }
            
            self.primaryButton.setTitle(newErrorType.primaryActionTitle, for: .normal)
            self.secondaryButton.setTitle(newErrorType.secondaryActionTitle, for: .normal)
            
            // Animate in
            UIView.animate(withDuration: 0.3, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
                self.containerView.alpha = 1
                self.containerView.transform = .identity
            })
        }
    }
}

// MARK: - Convenience Methods

extension ErrorViewController {
    static func showError(_ errorType: ErrorType, from viewController: UIViewController, delegate: ErrorViewControllerDelegate? = nil) {
        let errorVC = ErrorViewController(errorType: errorType)
        errorVC.delegate = delegate
        errorVC.modalPresentationStyle = .overFullScreen
        errorVC.modalTransitionStyle = .crossDissolve
        viewController.present(errorVC, animated: true)
    }
    
    static func createErrorType(from webViewError: Error) -> ErrorType {
        let nsError = webViewError as NSError
        
        // Check for network connectivity issues
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .noInternet
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                return .serverError
            case NSURLErrorBadServerResponse:
                if let httpResponse = nsError.userInfo["NSErrorFailingURLResponseKey"] as? HTTPURLResponse {
                    return .httpError(httpResponse.statusCode)
                }
                return .serverError
            default:
                return .unknown
            }
        }
        
        // Check for WKWebView specific errors
        if nsError.domain == "WKErrorDomain" {
            switch nsError.code {
            case 102: // WKErrorFrameLoadInterruptedByPolicyChange
                return .webError("Page load was interrupted")
            case 103: // WKErrorCannotShowURL
                return .webError("Cannot display this URL")
            case 104: // WKErrorCancelled
                return .webError("Request was cancelled")
            default:
                return .webError(webViewError.localizedDescription)
            }
        }
        
        return .unknown
    }
} 