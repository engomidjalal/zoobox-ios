import UIKit

class CameraViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .zooboxBackground
        // setupCamera() // Removed because function does not exist
    }

    @objc func onCameraTap() {
        CameraPermissionManager.checkCameraPermission(from: self) { granted in
            if granted {
                self.openCamera()
            } else {
                print("Camera permission denied")
            }
        }
    }

    func openCamera() {
        // Replace with your camera opening logic (UIImagePicker/AVCapture)
        let alert = UIAlertController(
            title: "Camera",
            message: "Camera would open here.",
            preferredStyle: .alert
        )
        alert.addAction(.init(title: "OK", style: .default))
        present(alert, animated: true)
    }
}



