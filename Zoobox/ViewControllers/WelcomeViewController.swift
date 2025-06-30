import UIKit

class WelcomeViewController: UIViewController {
    
    // MARK: - UI Components
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let getStartedButton = UIButton()
    private let backgroundGradientLayer = CAGradientLayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        animateIn()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradientLayer.frame = view.bounds
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Setup gradient background
        backgroundGradientLayer.colors = [
            UIColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1).cgColor,
            UIColor(red: 155/255, green: 89/255, blue: 182/255, alpha: 1).cgColor
        ]
        backgroundGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        backgroundGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(backgroundGradientLayer, at: 0)
        
        // Setup logo
        logoImageView.image = UIImage(named: "AppIcon") // Use app icon or create a custom logo
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.layer.cornerRadius = 30
        logoImageView.clipsToBounds = true
        view.addSubview(logoImageView)
        
        // Setup title
        titleLabel.text = "Welcome to Zoobox"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        
        // Setup subtitle
        subtitleLabel.text = "Your all-in-one delivery companion"
        subtitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        subtitleLabel.textColor = .white.withAlphaComponent(0.9)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        view.addSubview(subtitleLabel)
        
        // Setup get started button
        getStartedButton.setTitle("Get Started", for: .normal)
        getStartedButton.setTitleColor(UIColor(red: 52/255, green: 152/255, blue: 219/255, alpha: 1), for: .normal)
        getStartedButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        getStartedButton.backgroundColor = .white
        getStartedButton.layer.cornerRadius = 25
        getStartedButton.layer.shadowColor = UIColor.black.cgColor
        getStartedButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        getStartedButton.layer.shadowRadius = 12
        getStartedButton.layer.shadowOpacity = 0.2
        getStartedButton.addTarget(self, action: #selector(getStartedButtonTapped), for: .touchUpInside)
        view.addSubview(getStartedButton)
    }
    
    private func setupConstraints() {
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        getStartedButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Logo
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            // Get started button
            getStartedButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            getStartedButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            getStartedButton.widthAnchor.constraint(equalToConstant: 200),
            getStartedButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func animateIn() {
        // Initial state
        logoImageView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        logoImageView.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 30)
        titleLabel.alpha = 0
        subtitleLabel.transform = CGAffineTransform(translationX: 0, y: 30)
        subtitleLabel.alpha = 0
        getStartedButton.transform = CGAffineTransform(translationX: 0, y: 50)
        getStartedButton.alpha = 0
        
        // Animate in
        UIView.animate(withDuration: 0.8, delay: 0.2, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            self.logoImageView.transform = .identity
            self.logoImageView.alpha = 1
        })
        
        UIView.animate(withDuration: 0.6, delay: 0.6, options: [], animations: {
            self.titleLabel.transform = .identity
            self.titleLabel.alpha = 1
        })
        
        UIView.animate(withDuration: 0.6, delay: 0.8, options: [], animations: {
            self.subtitleLabel.transform = .identity
            self.subtitleLabel.alpha = 1
        })
        
        UIView.animate(withDuration: 0.6, delay: 1.0, options: [], animations: {
            self.getStartedButton.transform = .identity
            self.getStartedButton.alpha = 1
        })
    }
    
    @objc private func getStartedButtonTapped() {
        // Animate button press
        UIView.animate(withDuration: 0.1, animations: {
            self.getStartedButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.getStartedButton.transform = .identity
            }
        }
        
        // Present onboarding
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let onboardingVC = OnboardingViewController()
            onboardingVC.modalPresentationStyle = .fullScreen
            onboardingVC.modalTransitionStyle = .crossDissolve
            
            self.present(onboardingVC, animated: true)
        }
    }
} 