import UIKit
import CoreLocation
import SystemConfiguration

class ConnectivityViewController: UIViewController, CLLocationManagerDelegate, ConnectivityManagerDelegate {
    
    private let locationManager = CLLocationManager()
    private let connectivityManager = ConnectivityManager.shared
    private var isGpsEnabled = false
    private var isInternetConnected = false
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.1
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Connectivity Check"
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.textColor = .zooboxRed
        return label
    }()
    
    private let progressContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.zooboxRed.withAlphaComponent(0.1)
        view.layer.cornerRadius = 12
        return view
    }()
    
    private let progressBar: UIView = {
        let view = UIView()
        view.backgroundColor = .zooboxRed
        view.layer.cornerRadius = 10
        return view
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Checking connectivity..."
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.textColor = .zooboxRed
        return label
    }()
    
    private let progressLabel: UILabel = {
        let label = UILabel()
        label.text = "0%"
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .zooboxRed
        return label
    }()
    
    private let gpsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Enable GPS", for: .normal)
        button.setTitleColor(.zooboxTextLight, for: .normal)
        button.backgroundColor = UIColor.zooboxRed
        button.layer.cornerRadius = 12
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.isHidden = true
        return button
    }()
    
    private let internetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Enable Internet", for: .normal)
        button.setTitleColor(.zooboxTextLight, for: .normal)
        button.backgroundColor = UIColor.zooboxRed
        button.layer.cornerRadius = 12
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.isHidden = true
        return button
    }()
    
    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Retry", for: .normal)
        button.setTitleColor(.zooboxTextLight, for: .normal)
        button.backgroundColor = UIColor.zooboxRed
        button.layer.cornerRadius = 12
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.isHidden = true
        return button
    }()
    
    private var progressWidthConstraint: NSLayoutConstraint?
    private var currentProgress: Float = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.zooboxBackground
        setupUI()
        setupButtons()
        setupConnectivityManager()
        
        locationManager.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Start monitoring connectivity
        connectivityManager.startMonitoring()
        
        // Ensure we're on the main thread and view is in hierarchy
        DispatchQueue.main.async { [weak self] in
            self?.startChecking()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop monitoring when leaving this view
        connectivityManager.stopMonitoring()
    }
    
    private func setupUI() {
        view.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(progressContainer)
        progressContainer.addSubview(progressBar)
        containerView.addSubview(statusLabel)
        containerView.addSubview(progressLabel)
        containerView.addSubview(gpsButton)
        containerView.addSubview(internetButton)
        containerView.addSubview(retryButton)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        gpsButton.translatesAutoresizingMaskIntoConstraints = false
        internetButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            containerView.heightAnchor.constraint(equalToConstant: 280),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Progress container
            progressContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            progressContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            progressContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            progressContainer.heightAnchor.constraint(equalToConstant: 20),
            
            // Progress bar
            progressBar.topAnchor.constraint(equalTo: progressContainer.topAnchor, constant: 2),
            progressBar.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: -2),
            progressBar.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor, constant: 2),
            
            // Status label
            statusLabel.topAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Progress percentage
            progressLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            progressLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            progressLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Buttons
            gpsButton.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 20),
            gpsButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            gpsButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            gpsButton.heightAnchor.constraint(equalToConstant: 50),
            
            internetButton.topAnchor.constraint(equalTo: gpsButton.bottomAnchor, constant: 10),
            internetButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            internetButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            internetButton.heightAnchor.constraint(equalToConstant: 50),
            
            retryButton.topAnchor.constraint(equalTo: internetButton.bottomAnchor, constant: 10),
            retryButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            retryButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            retryButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Set initial progress bar width
        progressWidthConstraint = progressBar.widthAnchor.constraint(equalToConstant: 0)
        progressWidthConstraint?.isActive = true
    }
    
    private func setupButtons() {
        gpsButton.addTarget(self, action: #selector(gpsButtonTapped), for: .touchUpInside)
        internetButton.addTarget(self, action: #selector(internetButtonTapped), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
    }
    
    private func setupConnectivityManager() {
        connectivityManager.delegate = self
    }
    
    private func startChecking() {
        animateProgress(to: 0.2, status: "Checking GPS status...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.animateProgress(to: 0.4, status: "Checking internet connection...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.animateProgress(to: 0.6, status: "Verifying network connectivity...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.animateProgress(to: 0.8, status: "Finalizing connectivity check...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.checkConnectivity()
        }
    }
    
    private func animateProgress(to progress: Float, status: String) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
            self.currentProgress = progress
            self.statusLabel.text = status
            self.progressLabel.text = "\(Int(progress * 100))%"
            
            let containerWidth = self.progressContainer.frame.width - 4
            let newWidth = containerWidth * CGFloat(progress)
            self.progressWidthConstraint?.constant = newWidth
            self.view.layoutIfNeeded()
        }
    }
    
    private func checkConnectivity() {
        // Reset UI state
        gpsButton.isHidden = true
        internetButton.isHidden = true
        retryButton.isHidden = true
        
        // Check GPS and Internet using ConnectivityManager
        let connectivity = connectivityManager.checkConnectivity()
        isGpsEnabled = connectivity.isGPSEnabled
        isInternetConnected = connectivity.isInternetConnected
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateUI()
        }
    }
    
    private func updateUI() {
        if !isGpsEnabled {
            // GPS is disabled
            animateProgress(to: 1.0, status: "GPS is disabled. Enable location services to continue.")
            gpsButton.isHidden = false
            retryButton.isHidden = false
        } else if !isInternetConnected {
            // Internet is not available
            animateProgress(to: 1.0, status: "No Internet Connection. Please enable Wi-Fi or cellular data.")
            internetButton.isHidden = false
            retryButton.isHidden = false
        } else {
            // Everything is OK, proceed
            animateProgress(to: 1.0, status: "Connectivity OK! Proceeding...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.proceedToMain()
            }
        }
    }
    
    @objc private func gpsButtonTapped() {
        // Open Location Settings
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url) { [weak self] _ in
                // After returning from settings, check again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.checkConnectivity()
                }
            }
        }
    }
    
    @objc private func internetButtonTapped() {
        // Open Wi-Fi Settings
        if let url = URL(string: "App-Prefs:root=WIFI") {
            UIApplication.shared.open(url) { [weak self] _ in
                // After returning from settings, check again
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.checkConnectivity()
                }
            }
        } else {
            // Fallback to general settings if Wi-Fi settings URL doesn't work
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url) { [weak self] _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.checkConnectivity()
                    }
                }
            }
        }
    }
    
    @objc private func retryButtonTapped() {
        startChecking()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // Retry connectivity when location permission changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkConnectivity()
        }
    }
    
    // MARK: - ConnectivityManagerDelegate
    
    func connectivityManager(_ manager: ConnectivityManager, didUpdateConnectivityStatus status: ConnectivityStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch status {
            case .connected:
                self.isInternetConnected = true
                if self.isGpsEnabled {
                    // Both GPS and Internet are now available
                    self.updateUI()
                }
            case .disconnected:
                self.isInternetConnected = false
                self.updateUI()
            case .checking, .unknown:
                break
            }
        }
    }
    
    func connectivityManager(_ manager: ConnectivityManager, didUpdateGPSStatus enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isGpsEnabled = enabled
            if self.isInternetConnected && enabled {
                // Both GPS and Internet are now available
                self.updateUI()
            } else if !enabled {
                self.updateUI()
            }
        }
    }
    
    private func proceedToMain() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Check if we're still the top view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let topViewController = window.rootViewController?.topMostViewController(),
                  topViewController == self else {
                print("🚫 ConnectivityViewController not top view controller - skipping navigation")
                return
            }
            
            // Always go to permission check first, regardless of first run
            let permissionCheckVC = PermissionCheckViewController()
            permissionCheckVC.modalPresentationStyle = .fullScreen
            permissionCheckVC.modalTransitionStyle = .crossDissolve
            
            self.present(permissionCheckVC, animated: true) {
                print("✅ PermissionCheckViewController presented successfully")
            }
        }
    }
}
