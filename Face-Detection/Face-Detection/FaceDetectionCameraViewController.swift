//
//  FaceDetectionCameraViewController.swift
//  Face-Detection
//
//  Created by Faraz Ahmed Khan on 23/08/2023.
//

import UIKit
import AVFoundation
import Vision

protocol ImageCapturedDelegate: AnyObject {
    func didCaptureImage(image: UIImage?)
}

class FaceDetectionCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    
    //MARK: - Properties
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private let photoOutput = AVCapturePhotoOutput()
    private var drawings: [CAShapeLayer] = []
    private var numberOfFaces = 0
    private var faceRatio = 0.0
    private var isFlashOn: Bool = false
    private var isFrontCam: Bool = true
    private weak var delegate: ImageCapturedDelegate?
    
    //MARK: - UI Components
    fileprivate lazy var backButton: UIButton = {
        let b = UIButton()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(named: "back-arrow"), for: .normal)
        b.imageView?.contentMode = .scaleToFill
        b.isUserInteractionEnabled = true
        b.backgroundColor = .clear
        b.layer.cornerRadius = 10
        b.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backButtonTapped)))
        return b
    }()

    fileprivate lazy var captureButton: UIButton = {
        let b = UIButton()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(named: "camera_icon"), for: .normal)
        b.imageView?.contentMode = .scaleToFill
        b.isUserInteractionEnabled = false
        b.backgroundColor = .clear
        b.layer.cornerRadius = 10
        b.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapCaptureButton)))
        return b
    }()
    
    fileprivate lazy var flashButton: UIButton = {
        let b = UIButton()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(named: "flash_off"), for: .normal)
        b.imageView?.contentMode = .scaleToFill
        b.isUserInteractionEnabled = true
        b.layer.cornerRadius = 10
        b.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(toggleFlash)))
        return b
    }()
    
    fileprivate lazy var switchCameraButton: UIButton = {
        let b = UIButton()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(named: "switch_camera"), for: .normal)
        b.imageView?.contentMode = .scaleAspectFit
        b.isUserInteractionEnabled = true
        b.layer.cornerRadius = 10
        b.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(switchCamera)))
        return b
    }()
    
    //MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
        self.showCameraFeed()
        self.setupViews()
        self.initiateCameraConfigs()
    }
    
    private func initiateCameraConfigs() {
        self.addCameraInput(position: isFrontCam ? .front : .back)
        self.getCameraFrames()
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            self.captureSession.stopRunning()
            self.captureSession.startRunning()
            self.setupCameraForPhoto()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewLayer.frame = self.view.frame
    }
    
    fileprivate func setupCameraForPhoto() {
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }
    
    
    fileprivate func cameraAuthorizationStatus() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied:
            presentAccessAlertSettings(message: "Camera")
        case .restricted:
            presentAccessAlertSettings(message: "Camera")
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { success in
                if success {
                    print("Permission granted, proceed")
                } else {
                    DispatchQueue.main.async {
                        self.navigationController?.popViewController(animated: true)
                    }
                    
                }
            }
        @unknown default:
            break
        }
    }
    
    
    func presentAccessAlertSettings(message : String = "Camera" ) {
        let alertController = UIAlertController(title: "Access Denied",
                                      message: "\(message) access is denied",
                                      preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            DispatchQueue.main.async {
                self.navigationController?.popViewController(animated: true)
            }
        })
        alertController.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: { _ in
                    // Handle
                })
            }
        })

        self.present(alertController, animated: true)
    }

    
    fileprivate func setupViews() {
        self.view.addSubview(captureButton)
        captureButton.widthAnchor.constraint(equalToConstant: 80).isActive = true
        captureButton.heightAnchor.constraint(equalToConstant: 80).isActive = true
        captureButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        captureButton.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -80).isActive = true
        
        self.view.addSubview(flashButton)
        flashButton.widthAnchor.constraint(equalToConstant: 35).isActive = true
        flashButton.heightAnchor.constraint(equalToConstant: 35).isActive = true
        flashButton.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 15).isActive = true
        flashButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        
        self.view.addSubview(switchCameraButton)
        switchCameraButton.widthAnchor.constraint(equalToConstant: 35).isActive = true
        switchCameraButton.heightAnchor.constraint(equalToConstant: 35).isActive = true
        switchCameraButton.leadingAnchor.constraint(equalTo: self.flashButton.leadingAnchor).isActive = true
        switchCameraButton.topAnchor.constraint(equalTo: self.flashButton.bottomAnchor, constant: 15).isActive = true
        
        self.view.addSubview(backButton)
        backButton.widthAnchor.constraint(equalToConstant: 25).isActive = true
        backButton.heightAnchor.constraint(equalToConstant: 25).isActive = true
        backButton.leadingAnchor.constraint(equalTo: self.flashButton.leadingAnchor).isActive = true
        backButton.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 35).isActive = true
    }
    
    @objc func backButtonTapped() {
        self.navigationController?.popViewController(animated: true)
    }
    
    //MARK: - Capture Image
    
    @objc private func handleTakePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        if let photoPreviewType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoPreviewType]
            photoSettings.flashMode = isFlashOn ? .on : .off
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    @objc private func didTapCaptureButton() {
        self.handleTakePhoto()
    }
    
    fileprivate func changeCameraButtonState(isEnabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.captureButton.isUserInteractionEnabled = isEnabled
        }
    }
    
    fileprivate func changeFlashButtonState() {
        DispatchQueue.main.async { [weak self] in
            self?.flashButton.setImage(UIImage(named: (self?.isFlashOn ?? false) ? "flash_on" : "flash_off"), for: .normal)
        }
    }
    
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        let previewImage = UIImage(data: imageData)
        self.navigationController?.popViewController(animated: true)
        self.delegate?.didCaptureImage(image: previewImage)
    }
    
    //MARK: - Camera Setup
    private func addCameraInput(position: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: position).devices.first else {
            print("No back camera device found, please make sure to run SimpleLaneDetection in an iOS device and not a simulator")
            showToast(message: "No back camera device found")
            return
        }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        
        if let currentCameraInput = captureSession.inputs.first {
            captureSession.removeInput(currentCameraInput)
        }
        
        if self.captureSession.canAddInput(cameraInput) {
            self.captureSession.addInput(cameraInput)
        }
    }
    
    private func showCameraFeed() {
        self.previewLayer.videoGravity = .resizeAspect
        self.view.layer.addSublayer(self.previewLayer)
        self.previewLayer.frame = self.view.frame
    }
    
    private func getCameraFrames() {
        self.videoDataOutput = nil
        self.videoDataOutput = AVCaptureVideoDataOutput()
        self.videoDataOutput?.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        self.videoDataOutput?.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        self.captureSession.addOutput(self.videoDataOutput!)
        guard let connection = self.videoDataOutput?.connection(with: AVMediaType.video),
              connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
    
    //MARK: - Face Detection
    private func detectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                if let results = request.results as? [VNFaceObservation] {
                    self.changeCameraButtonState(isEnabled: results.count == 1)
                    self.numberOfFaces = results.count
                    if results.count != 1 {
                        self.clearDrawings()
                        return
                    }
                    self.handleFaceDetectionResults(results)
                } else {
                    self.numberOfFaces = 0
                    self.clearDrawings()
                }
            }
        })
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
    
    
    private func handleFaceDetectionResults(_ observedFaces: [VNFaceObservation]) {
        self.clearDrawings()
        let facesBoundingBoxes: [CAShapeLayer] = observedFaces.map({ (observedFace: VNFaceObservation) -> CAShapeLayer in
            let faceBoundingBoxOnScreen = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox)
            self.faceRatio = self.rectIntersectionInPerc(r1: self.view.frame, r2: faceBoundingBoxOnScreen)
            self.changeCameraButtonState(isEnabled: self.faceRatio >= 18)
            if self.faceRatio < 18 {
                self.showToast(message: "Please bring phone near to your face to capture clear image")
                self.clearDrawings()
                return CAShapeLayer()
            }
            let faceBoundingBoxPath = CGPath(rect: faceBoundingBoxOnScreen, transform: nil)
            let faceBoundingBoxShape = CAShapeLayer()
            faceBoundingBoxShape.path = faceBoundingBoxPath
            faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
            faceBoundingBoxShape.strokeColor = UIColor.green.cgColor
            return faceBoundingBoxShape
        })
        facesBoundingBoxes.forEach({ faceBoundingBox in self.view.layer.addSublayer(faceBoundingBox) })
        self.drawings = facesBoundingBoxes
    }
    private func clearDrawings() {
        self.drawings.forEach({ drawing in drawing.removeFromSuperlayer() })
    }
    
    //MARK: - Comparing frames
    func rectIntersectionInPerc(r1: CGRect, r2: CGRect) -> CGFloat {
        if r1.intersects(r2) {
            let interRect: CGRect = r1.intersection(r2)
            let intersectionArea = interRect.width * interRect.height
            let rectArea = r1.width * r1.height
            return (intersectionArea / rectArea) * 100.0
        }
        return 0
    }
    
    //MARK: - Switch Camera
    @objc func switchCamera() {
        if let currentCameraInput = captureSession.inputs.first {
            captureSession.removeInput(currentCameraInput)
            var newCamera: AVCaptureDevice
            newCamera = AVCaptureDevice.default(for: AVMediaType.video)!
            
            if (currentCameraInput as! AVCaptureDeviceInput).device.position == .back {
                isFrontCam = true
                UIView.transition(with: self.view, duration: 0.15, options: .transitionFlipFromLeft, animations: {
                    newCamera = self.cameraWithPosition(.front)!
                }, completion: nil)
            } else {
                isFrontCam = false
                UIView.transition(with: self.view, duration: 0.15, options: .transitionFlipFromRight, animations: {
                    newCamera = self.cameraWithPosition(.back)!
                }, completion: nil)
            }
            do {
                if let currentCameraInput = captureSession.inputs.first {
                    captureSession.removeInput(currentCameraInput)
                }

                if captureSession.canAddInput(try AVCaptureDeviceInput(device: newCamera)) {
                    try self.captureSession.addInput(AVCaptureDeviceInput(device: newCamera))
                }
            }
            catch {
                print("error: \(error.localizedDescription)")
            }
        }
        self.captureSession.removeOutput(videoDataOutput!)
        self.videoDataOutput?.setSampleBufferDelegate(nil, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        self.initiateCameraConfigs()
    }
    
    func cameraWithPosition(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceDescoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: AVMediaType.video, position: AVCaptureDevice.Position.unspecified)
        
        for device in deviceDescoverySession.devices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
    
    
    //MARK: Flash Utility Methods
    @objc func toggleFlash() {
        var device : AVCaptureDevice!
        
        if #available(iOS 10.0, *) {
            let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDuoCamera], mediaType: AVMediaType.video, position: .unspecified)
            let devices = videoDeviceDiscoverySession.devices
            device = devices.first!
            
        } else {
            // Fallback on earlier versions
            device = AVCaptureDevice.default(device.deviceType, for: AVMediaType.video, position: .back)//.defaultDevice(withMediaType: AVMediaTypeVideo)
        }
        
        if ((device as AnyObject).hasMediaType(AVMediaType.video))
        {
            if (device.hasTorch)
            {
                if device.isTorchActive == false {
                    isFlashOn.toggle()
                    changeFlashButtonState()
                } else {
                    isFlashOn = false
                    changeFlashButtonState()
                }
            }
        }
    }
    
}

extension FaceDetectionCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }
        self.detectFace(in: frame)
        //Retrieving EXIF data of camara frame buffer
        let rawMetadata = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
        let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
        let exifData = metadata.value(forKey: "{Exif}") as? NSMutableDictionary
        
        let FNumber : Double = exifData?["FNumber"] as! Double
        let ExposureTime : Double = exifData?["ExposureTime"] as! Double
        let ISOSpeedRatingsArray = exifData!["ISOSpeedRatings"] as? NSArray
        let ISOSpeedRatings : Double = ISOSpeedRatingsArray![0] as! Double
        let CalibrationConstant : Double = 50
        
        //Calculating the luminosity
        let luminosity : Double = (CalibrationConstant * FNumber * FNumber ) / ( ExposureTime * ISOSpeedRatings )
        
        self.changeCameraButtonState(isEnabled: luminosity >= 4 && self.numberOfFaces == 1 && self.faceRatio >= 18)
        if luminosity < 4 {
            self.showToast(message: "Not enough light")
            self.clearDrawings()
        }
        
    }
    
}


extension UIViewController {
    
    func showToast(message : String, font: UIFont = .boldSystemFont(ofSize: 12.0)) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let toastLabel = UILabel()
            toastLabel.translatesAutoresizingMaskIntoConstraints = false
            toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            toastLabel.textColor = UIColor.white
            toastLabel.font = font
            toastLabel.textAlignment = .center;
            toastLabel.text = message
            toastLabel.alpha = 1.0
            toastLabel.layer.cornerRadius = 10
            toastLabel.adjustsFontSizeToFitWidth = true
            toastLabel.clipsToBounds  =  true
            for subview in self.view.subviews {
                if subview is UILabel {
                    subview.removeFromSuperview()
                    // this is a button
                }
            }
            self.view.addSubview(toastLabel)
            toastLabel.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.85).isActive = true
            toastLabel.heightAnchor.constraint(equalToConstant: 50).isActive = true
            toastLabel.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
            toastLabel.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
            
            UIView.animate(withDuration: 1.0, delay: 0.1, options: .curveEaseOut, animations: {
                toastLabel.alpha = 0.0
            }, completion: {(isCompleted) in
                toastLabel.removeFromSuperview()
            })
        }
    }
}

