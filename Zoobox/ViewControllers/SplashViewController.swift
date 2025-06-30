import UIKit
import AVFoundation
import AVKit

class SplashViewController: UIViewController {
    
    private var playerViewController: AVPlayerViewController?
    private var player: AVPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoPlayer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Ensure we're on the main thread and view is in hierarchy
        DispatchQueue.main.async { [weak self] in
            self?.playVideo()
        }
    }
    
    private func setupVideoPlayer() {
        // Set background color to white (matching Android app)
        view.backgroundColor = .zooboxBackground
        
        // Get the video file path
        guard let videoPath = Bundle.main.path(forResource: "splash", ofType: "mp4") else {
            print("Could not find splash.mp4 in bundle")
            // If video not found, proceed to next screen after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.proceedToConnectivityCheck()
            }
            return
        }
        
        let videoURL = URL(fileURLWithPath: videoPath)
        player = AVPlayer(url: videoURL)
        
        // Create player view controller
        playerViewController = AVPlayerViewController()
        playerViewController?.player = player
        playerViewController?.showsPlaybackControls = false
        playerViewController?.videoGravity = .resizeAspectFill
        
        // Add player as child view controller
        if let playerVC = playerViewController {
            addChild(playerVC)
            view.addSubview(playerVC.view)
            
            // Set constraints to fill entire screen
            playerVC.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                playerVC.view.topAnchor.constraint(equalTo: view.topAnchor),
                playerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                playerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                playerVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            playerVC.didMove(toParent: self)
        }
    }
    
    private func playVideo() {
        guard let player = player else { return }
        
        // Add notification for when video ends
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        // Start playing
        player.play()
        
        // Fallback timer in case video doesn't load (5 seconds like Android)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.proceedToConnectivityCheck()
        }
    }
    
    @objc private func playerDidFinishPlaying() {
        // Video finished playing, proceed to next screen
        proceedToConnectivityCheck()
    }
    
    private func proceedToConnectivityCheck() {
        // Remove observer
        NotificationCenter.default.removeObserver(self)
        
        // Clean up player first
        self.player?.pause()
        self.player = nil
        self.playerViewController?.removeFromParent()
        self.playerViewController = nil
        
        // Ensure we're on main thread and view is in hierarchy
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Check if we're still the top view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let topViewController = window.rootViewController?.topMostViewController(),
                  topViewController == self else {
                print("🚫 SplashViewController not top view controller - skipping navigation")
                return
            }
            
            // Navigate to ConnectivityViewController
            let connectivityVC = ConnectivityViewController()
            connectivityVC.modalPresentationStyle = .fullScreen
            connectivityVC.modalTransitionStyle = .crossDissolve
            
            self.present(connectivityVC, animated: true) {
                print("✅ ConnectivityViewController presented successfully")
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        player?.pause()
        player = nil
    }
}
