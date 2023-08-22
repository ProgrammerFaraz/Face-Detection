# Face Detection Camera Swift


[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/ProgrammerFaraz/Face-Detection)
[![License](https://img.shields.io/badge/license-MIT-gray)](https://github.com/ProgrammerFaraz/Face-Detection)

## Requirements

* Xcode 13.0 or higher.
* iOS 15.5 or higher.
  
## Usage
* Initialize viewcontroller in any class and use easy way.
```swift
let vc = FaceDetectionCameraViewController()
vc.delegate = self
self.navigationController?.pushViewController(vc, animated: true)
```
* Implement delegate method and use the captured image.
```swift
extension ViewController: ImageCapturedDelegate {
    func didCaptureImage(image: UIImage?) {
        //show image
    }
}
```
## Author

ProgrammerFaraz, farazahmedkhan18@gmail.com


## License

Face-Detection is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
