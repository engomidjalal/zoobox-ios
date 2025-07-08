import UIKit

class LoadingIndicatorManager {
    static let shared = LoadingIndicatorManager()
    
    private var loadingContainerView: UIView?
    private var loadingIndicator: UIActivityIndicatorView?
    private var isShowing = false
    private var topConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?
    private var bottomConstraint: NSLayoutConstraint?
    
    private init() {}
    
    // MARK: - Public Methods
    
    func showLoadingIndicator(on viewController: UIViewController, message: String? = nil) {
        guard !isShowing else { 
            print("📱 [LoadingIndicator] Already showing, skipping")
            return 
        }
        
        print("📱 [LoadingIndicator] showLoadingIndicator called")
        print("⏰ [LoadingIndicator] showLoadingIndicator time: \(Date())")
        print("📱 [LoadingIndicator] Message: \(message ?? "No message")")
        
        DispatchQueue.main.async { [weak self] in
            self?.createAndShowLoadingIndicator(on: viewController, message: message)
        }
    }
    
    func hideLoadingIndicator() {
        guard isShowing else { 
            print("📱 [LoadingIndicator] Not showing, skipping hide")
            return 
        }
        
        print("📱 [LoadingIndicator] hideLoadingIndicator called")
        print("⏰ [LoadingIndicator] hideLoadingIndicator time: \(Date())")
        
        DispatchQueue.main.async { [weak self] in
            self?.removeLoadingIndicator()
        }
    }
    
    func showLoadingIndicatorWithCompletion(on viewController: UIViewController, 
                                           message: String? = nil, 
                                           completion: @escaping () -> Void) {
        showLoadingIndicator(on: viewController, message: message)
        
        // Add a small delay to ensure smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion()
        }
    }
    
    // MARK: - Private Methods
    
    private func createAndShowLoadingIndicator(on viewController: UIViewController, message: String? = nil) {
        print("📱 [LoadingIndicator] createAndShowLoadingIndicator called")
        
        // Remove any existing indicator
        removeLoadingIndicator()
        
        // Find the best superview: window preferred, fallback to viewController.view
        let targetWindow: UIWindow? = {
            if let window = viewController.view.window {
                print("📱 [LoadingIndicator] Using viewController.view.window")
                return window
            }
            // iOS 13+
            if #available(iOS 13.0, *) {
                let window = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first { $0.isKeyWindow }
                print("📱 [LoadingIndicator] Using keyWindow: \(window != nil)")
                return window
            } else {
                let window = UIApplication.shared.keyWindow
                print("📱 [LoadingIndicator] Using legacy keyWindow: \(window != nil)")
                return window
            }
        }()
        
        let superview: UIView? = targetWindow ?? viewController.view
        guard let parent = superview else { 
            print("❌ [LoadingIndicator] No parent view found")
            return 
        }
        
        print("📱 [LoadingIndicator] Using parent: \(type(of: parent))")
        
        // Create loading container view
        let containerView = UIView()
        containerView.backgroundColor = UIColor.white
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.alpha = 0
        
        // Add a subtle border to make it more visible for debugging
        containerView.layer.borderWidth = 1.0
        containerView.layer.borderColor = UIColor.red.cgColor
        
        // Create loading indicator with red color (following Apple guidelines)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = UIColor.systemRed
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        
        // Add indicator to container
        containerView.addSubview(indicator)
        
        // Add optional message label
        if let message = message, !message.isEmpty {
            let messageLabel = UILabel()
            messageLabel.text = message
            messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            messageLabel.textColor = UIColor.secondaryLabel
            messageLabel.textAlignment = .center
            messageLabel.numberOfLines = 0
            messageLabel.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(messageLabel)
            
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -20),
                messageLabel.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 16),
                messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
                messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
                messageLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ])
        }
        
        // Add container to parent with high z-index
        parent.addSubview(containerView)
        parent.bringSubviewToFront(containerView)
        
        // Ensure it's on top of everything
        containerView.layer.zPosition = 1000
        
        print("📱 [LoadingIndicator] Container added to parent")
        print("📱 [LoadingIndicator] Parent subviews count: \(parent.subviews.count)")
        print("📱 [LoadingIndicator] Container is in hierarchy: \(containerView.superview != nil)")
        
        // Set up constraints to fill parent
        let top = containerView.topAnchor.constraint(equalTo: parent.topAnchor)
        let leading = containerView.leadingAnchor.constraint(equalTo: parent.leadingAnchor)
        let trailing = containerView.trailingAnchor.constraint(equalTo: parent.trailingAnchor)
        let bottom = containerView.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        NSLayoutConstraint.activate([top, leading, trailing, bottom])
        self.topConstraint = top
        self.leadingConstraint = leading
        self.trailingConstraint = trailing
        self.bottomConstraint = bottom
        
        // Store references
        self.loadingContainerView = containerView
        self.loadingIndicator = indicator
        self.isShowing = true
        
        print("📱 [LoadingIndicator] Loading indicator created and added to view")
        
        // Animate in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            containerView.alpha = 1.0
        } completion: { _ in
            print("📱 [LoadingIndicator] Loading indicator animation completed")
            print("📱 [LoadingIndicator] Container view alpha: \(containerView.alpha)")
            print("📱 [LoadingIndicator] Container view is hidden: \(containerView.isHidden)")
            print("📱 [LoadingIndicator] Container view frame: \(containerView.frame)")
        }
    }
    
    private func removeLoadingIndicator() {
        guard let containerView = loadingContainerView else { 
            print("📱 [LoadingIndicator] No container view to remove")
            return 
        }
        
        print("📱 [LoadingIndicator] Starting to remove loading indicator")
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            containerView.alpha = 0.0
        }) { _ in
            containerView.removeFromSuperview()
            self.loadingContainerView = nil
            self.loadingIndicator = nil
            self.isShowing = false
            self.topConstraint = nil
            self.leadingConstraint = nil
            self.trailingConstraint = nil
            self.bottomConstraint = nil
            print("📱 [LoadingIndicator] Loading indicator removed successfully")
        }
    }
}

// MARK: - Convenience Extensions

extension UIViewController {
    func showLoadingIndicator(message: String? = nil) {
        LoadingIndicatorManager.shared.showLoadingIndicator(on: self, message: message)
    }
    
    func hideLoadingIndicator() {
        LoadingIndicatorManager.shared.hideLoadingIndicator()
    }
    
    func showLoadingIndicatorWithCompletion(message: String? = nil, completion: @escaping () -> Void) {
        LoadingIndicatorManager.shared.showLoadingIndicatorWithCompletion(on: self, message: message, completion: completion)
    }
} 