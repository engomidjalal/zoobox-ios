import UIKit
import CoreLocation
import SystemConfiguration

class ConnectivityViewController: UIViewController, CLLocationManagerDelegate, ConnectivityManagerDelegate {
    
    private let locationManager = CLLocationManager()
    private let connectivityManager = ConnectivityManager.shared
    private var isGpsEnabled = false
    private var isInternetConnected = false
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Checking Connectivity..."
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .zooboxRed
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .zooboxRed
        indicator.startAnimating()
        return indicator
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
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        return stack
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.zooboxBackground // White background instead of red
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
            self?.checkConnectivity()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop monitoring when leaving this view
        connectivityManager.stopMonitoring()
    }
    
    private func setupUI() {
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews to stack view
        stackView.addArrangedSubview(statusLabel)
        stackView.addArrangedSubview(activityIndicator)
        stackView.addArrangedSubview(gpsButton)
        stackView.addArrangedSubview(internetButton)
        stackView.addArrangedSubview(retryButton)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            gpsButton.heightAnchor.constraint(equalToConstant: 50),
            gpsButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            
            internetButton.heightAnchor.constraint(equalToConstant: 50),
            internetButton.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            
            retryButton.heightAnchor.constraint(equalToConstant: 50),
            retryButton.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
    }
    
    private func setupButtons() {
        gpsButton.addTarget(self, action: #selector(gpsButtonTapped), for: .touchUpInside)
        internetButton.addTarget(self, action: #selector(internetButtonTapped), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
    }
    
    private func setupConnectivityManager() {
        connectivityManager.delegate = self
    }
    
    private func checkConnectivity() {
        // Reset UI state
        activityIndicator.startAnimating()
        gpsButton.isHidden = true
        internetButton.isHidden = true
        retryButton.isHidden = true
        statusLabel.text = "Checking Connectivity..."
        
        // Check GPS and Internet using ConnectivityManager
        let connectivity = connectivityManager.checkConnectivity()
        isGpsEnabled = connectivity.isGPSEnabled
        isInternetConnected = connectivity.isInternetConnected
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateUI()
        }
    }
    
    private func updateUI() {
        activityIndicator.stopAnimating()
        
        if !isGpsEnabled {
            // GPS is disabled
            statusLabel.text = "GPS is disabled.\nEnable location services to continue."
            gpsButton.isHidden = false
            retryButton.isHidden = false
        } else if !isInternetConnected {
            // Internet is not available
            statusLabel.text = "No Internet Connection.\nPlease enable Wi-Fi or cellular data."
            internetButton.isHidden = false
            retryButton.isHidden = false
        } else {
            // Everything is OK, proceed
            statusLabel.text = "Connectivity OK!\nProceeding..."
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
        checkConnectivity()
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
