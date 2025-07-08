import AVFoundation
import UIKit

final class CameraPermissionManager {
    static func checkCameraPermission(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        case .authorized:
            completion(true)
        case .denied, .restricted:
            showPermissionDeniedAlert(from: viewController)
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    static func showPermissionDeniedAlert(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Camera Access",
            message: "Camera access helps you scan QR codes and upload documents, but is not required to use the app. You can enable it in Settings or continue without it.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Continue Anyway", style: .default) { _ in
            // Continue without camera permission
        })
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        // iPad-specific popover presentation
        if UIDevice.current.isIPad {
            if let popover = alert.popoverPresentationController {
                popover.sourceView = viewController.view
                popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        viewController.present(alert, animated: true)
    }
}



