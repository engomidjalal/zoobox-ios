import Foundation
import SystemConfiguration
import CoreLocation
import Network

protocol ConnectivityManagerDelegate: AnyObject {
    func connectivityManager(_ manager: ConnectivityManager, didUpdateConnectivityStatus status: ConnectivityStatus)
    func connectivityManager(_ manager: ConnectivityManager, didUpdateGPSStatus enabled: Bool)
}

enum ConnectivityStatus {
    case checking
    case connected
    case disconnected
    case unknown
}

class ConnectivityManager: NSObject {
    static let shared = ConnectivityManager()
    
    weak var delegate: ConnectivityManagerDelegate?
    
    private let networkMonitor = NWPathMonitor()
    private let locationManager = CLLocationManager()
    private var isMonitoring = false
    
    private(set) var currentConnectivityStatus: ConnectivityStatus = .unknown
    private(set) var isGPSEnabled: Bool = false
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startNetworkMonitoring()
        updateGPSStatus()
        
        print("📡 ConnectivityManager: Started monitoring")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        networkMonitor.cancel()
        
        print("📡 ConnectivityManager: Stopped monitoring")
    }
    
    func checkConnectivity() -> (isGPSEnabled: Bool, isInternetConnected: Bool) {
        let gpsEnabled = CLLocationManager.locationServicesEnabled()
        let internetConnected = isNetworkReachable()
        
        // Update internal state
        isGPSEnabled = gpsEnabled
        currentConnectivityStatus = internetConnected ? .connected : .disconnected
        
        // Notify delegate
        delegate?.connectivityManager(self, didUpdateGPSStatus: gpsEnabled)
        delegate?.connectivityManager(self, didUpdateConnectivityStatus: currentConnectivityStatus)
        
        return (gpsEnabled, internetConnected)
    }
    
    // MARK: - Private Methods
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkPathUpdate(path)
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let newStatus: ConnectivityStatus
        
        switch path.status {
        case .satisfied:
            newStatus = .connected
        case .unsatisfied:
            newStatus = .disconnected
        case .requiresConnection:
            newStatus = .disconnected
        @unknown default:
            newStatus = .unknown
        }
        
        if newStatus != currentConnectivityStatus {
            currentConnectivityStatus = newStatus
            delegate?.connectivityManager(self, didUpdateConnectivityStatus: newStatus)
        }
    }
    
    private func updateGPSStatus() {
        let newGPSStatus = CLLocationManager.locationServicesEnabled()
        if newGPSStatus != isGPSEnabled {
            isGPSEnabled = newGPSStatus
            delegate?.connectivityManager(self, didUpdateGPSStatus: newGPSStatus)
        }
    }
    
    private func isNetworkReachable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        return isReachable && !needsConnection
    }
}

// MARK: - CLLocationManagerDelegate
extension ConnectivityManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        updateGPSStatus()
    }
} 