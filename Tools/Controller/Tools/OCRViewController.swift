/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the main app implementation using Vision.
*/

import Photos
import UIKit
import Vision

class OCRViewController: BaseViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @objc func generateBtnAction(){
        // Convert from UIImageOrientation to CGImagePropertyOrientation.
        let cgOrientation = CGImagePropertyOrientation(originalImage.imageOrientation)
        
        // Fire off request based on URL of chosen photo.
        guard let cgImage = originalImage.cgImage else {
            return
        }
        performVisionRequest(image: cgImage,
                             orientation: cgOrientation)
    }
    
    lazy var generateBtn : UIButton = {
        let generateBtn = UIButton(frame: .zero)
        generateBtn.setTitle("提取", for: .normal)
        generateBtn.setTitleColor(.systemBlue, for: .normal)
        generateBtn.addTarget(self, action: #selector(generateBtnAction), for: .touchUpInside)
        generateBtn.layer.cornerRadius = 10
        generateBtn.clipsToBounds = true
        generateBtn.layer.borderWidth = 1
        generateBtn.layer.borderColor = UIColor.systemBlue.cgColor
        return generateBtn
    }()
    
    lazy var imageView : UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var selectBtn : UIButton = {
        let selectBtn = UIButton(frame: .zero)
        selectBtn.setTitle("拍照或选取照片", for: .normal)
        selectBtn.setTitleColor(.systemBlue, for: .normal)
        selectBtn.addTarget(self, action: #selector(promptPhoto), for: .touchUpInside)
        selectBtn.layer.cornerRadius = 10
        selectBtn.clipsToBounds = true
        selectBtn.layer.borderWidth = 1
        selectBtn.layer.borderColor = UIColor.systemBlue.cgColor
        return selectBtn
    }()
    
    lazy var scrollView : UIScrollView = {
        let scrollView = UIScrollView(frame: .zero)
        let height: CGFloat = (.screenW - 30) * 9 / 16 + 110 + .safeAreaBottomHeight
        scrollView.contentSize = CGSize(width: 0, height: height)
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: -CGFloat.safeAreaBottomHeight, right: 0)
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    // Layer into which to draw bounding box paths.
    var pathLayer: CALayer?
    
    // Image parameters for reuse throughout app
    var imageWidth: CGFloat = 0
    var imageHeight: CGFloat = 0
    
    var originalImage = UIImage()
    
    // Background is black, so display status bar in white.
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Tapping the image view brings up the photo picker.
        title = "OCR"
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(CGFloat.topHeight)
            make.left.equalToSuperview().offset(15)
            make.right.equalToSuperview().offset(-15)
            make.bottom.equalToSuperview()
        }
        scrollView.addSubview(selectBtn)
        selectBtn.snp.makeConstraints { (make) in
            make.left.equalToSuperview()
            make.width.equalTo(CGFloat.screenW - 30)
            make.top.equalToSuperview()
            make.height.equalTo(40)
        }
    }
    
    @objc
    func promptPhoto() {
        
        let prompt = UIAlertController(title: "选取一张照片",
                                       message: nil,
                                       preferredStyle: .actionSheet)
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        
        func presentCamera(_ _: UIAlertAction) {
            imagePicker.sourceType = .camera
            self.present(imagePicker, animated: true)
        }
        
        let cameraAction = UIAlertAction(title: "拍照",
                                         style: .default,
                                         handler: presentCamera)
        
        func presentLibrary(_ _: UIAlertAction) {
            imagePicker.sourceType = .photoLibrary
            self.present(imagePicker, animated: true)
        }
        
        let libraryAction = UIAlertAction(title: "从相册中选取",
                                          style: .default,
                                          handler: presentLibrary)
        
        func presentAlbums(_ _: UIAlertAction) {
            imagePicker.sourceType = .savedPhotosAlbum
            self.present(imagePicker, animated: true)
        }
        
        let cancelAction = UIAlertAction(title: "取消",
                                         style: .cancel,
                                         handler: nil)
        
        prompt.addAction(cameraAction)
        prompt.addAction(libraryAction)
        prompt.addAction(cancelAction)
        
        self.present(prompt, animated: true, completion: nil)
    }
    
    // MARK: - Helper Methods
    
    /// - Tag: PreprocessImage
    func scaleAndOrient(image: UIImage) -> UIImage {
        
        // Set a default value for limiting image size.
        let maxResolution: CGFloat = 640
        
        guard let cgImage = image.cgImage else {
            debugPrint("UIImage has no CGImage backing it!")
            return image
        }
        
        // Compute parameters for transform.
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        var transform = CGAffineTransform.identity
        
        var bounds = CGRect(x: 0, y: 0, width: width, height: height)
        
        if width > maxResolution ||
            height > maxResolution {
            let ratio = width / height
            if width > height {
                bounds.size.width = maxResolution
                bounds.size.height = round(maxResolution / ratio)
            } else {
                bounds.size.width = round(maxResolution * ratio)
                bounds.size.height = maxResolution
            }
        }
        
        let scaleRatio = bounds.size.width / width
        let orientation = image.imageOrientation
        switch orientation {
        case .up:
            transform = .identity
        case .down:
            transform = CGAffineTransform(translationX: width, y: height).rotated(by: .pi)
        case .left:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: 0, y: width).rotated(by: 3.0 * .pi / 2.0)
        case .right:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: height, y: 0).rotated(by: .pi / 2.0)
        case .upMirrored:
            transform = CGAffineTransform(translationX: width, y: 0).scaledBy(x: -1, y: 1)
        case .downMirrored:
            transform = CGAffineTransform(translationX: 0, y: height).scaledBy(x: 1, y: -1)
        case .leftMirrored:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(translationX: height, y: width).scaledBy(x: -1, y: 1).rotated(by: 3.0 * .pi / 2.0)
        case .rightMirrored:
            let boundsHeight = bounds.size.height
            bounds.size.height = bounds.size.width
            bounds.size.width = boundsHeight
            transform = CGAffineTransform(scaleX: -1, y: 1).rotated(by: .pi / 2.0)
        default:
            transform = .identity
        }
        
        return UIGraphicsImageRenderer(size: bounds.size).image { rendererContext in
            let context = rendererContext.cgContext
            
            if orientation == .right || orientation == .left {
                context.scaleBy(x: -scaleRatio, y: scaleRatio)
                context.translateBy(x: -height, y: 0)
            } else {
                context.scaleBy(x: scaleRatio, y: -scaleRatio)
                context.translateBy(x: 0, y: -height)
            }
            context.concatenate(transform)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
    
    func presentAlert(_ title: String, error: NSError) {
        // Always present alert on main thread.
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title,
                                                    message: error.localizedDescription,
                                                    preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK",
                                         style: .default) { _ in
                                            // Do nothing -- simply dismiss alert.
            }
            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    // MARK: - UIImagePickerControllerDelegate
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        // Dismiss picker, returning to original root viewController.
        dismiss(animated: true, completion: nil)
    }
    
    internal func imagePickerController(_ picker: UIImagePickerController,
                                        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        // Extract chosen image.
        originalImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
        
        // Display image on screen.
        show(originalImage)
                
        // Dismiss the picker to return to original view controller.
        dismiss(animated: true, completion: nil)
    }
    
    func show(_ image: UIImage) {
        
        // Remove previous paths & image
        pathLayer?.removeFromSuperlayer()
        pathLayer = nil
        imageView.image = nil
        
        if !scrollView.subviews.contains(imageView) {
            scrollView.addSubview(imageView)
            imageView.snp.makeConstraints { (make) in
                make.left.equalToSuperview()
                make.width.equalTo(CGFloat.screenW - 30)
                make.height.equalTo((CGFloat.screenW - 30) * image.size.height / image.size.width)
                make.top.equalTo(self.selectBtn.snp.bottom).offset(15)
            }
            scrollView.addSubview(generateBtn)
            generateBtn.snp.makeConstraints { (make) in
                make.left.equalToSuperview()
                make.width.equalTo(CGFloat.screenW - 30)
                make.height.equalTo(40)
                make.top.equalTo(self.imageView.snp.bottom).offset(15)
            }
        }
        
        scrollView.contentSize = CGSize(width: 0, height: 40 + 15 + (CGFloat.screenW - 30) * image.size.height / image.size.width + 15 + 40 + CGFloat.safeAreaBottomHeight)
        
        // Account for image orientation by transforming view.
        let correctedImage = scaleAndOrient(image: image)
        
        // Place photo inside imageView.
        imageView.image = correctedImage
        
        // Transform image to fit screen.
        guard let cgImage = correctedImage.cgImage else {
            debugPrint("Trying to show an image not backed by CGImage!")
            return
        }
        
        let fullImageWidth = CGFloat(cgImage.width)
        let fullImageHeight = CGFloat(cgImage.height)
        
        let imageFrame = imageView.frame
        let widthRatio = fullImageWidth / imageFrame.width
        let heightRatio = fullImageHeight / imageFrame.height
        
        // ScaleAspectFit: The image will be scaled down according to the stricter dimension.
        let scaleDownRatio = max(widthRatio, heightRatio)
        
        // Cache image dimensions to reference when drawing CALayer paths.
        imageWidth = fullImageWidth / scaleDownRatio
        imageHeight = fullImageHeight / scaleDownRatio
        
        // Prepare pathLayer to hold Vision results.
        let xLayer = (imageFrame.width - imageWidth) / 2
        let yLayer = imageView.frame.minY + (imageFrame.height - imageHeight) / 2
        let drawingLayer = CALayer()
        drawingLayer.bounds = CGRect(x: xLayer, y: yLayer, width: imageWidth, height: imageHeight)
        drawingLayer.anchorPoint = CGPoint.zero
        drawingLayer.position = CGPoint(x: xLayer, y: yLayer)
        drawingLayer.opacity = 0.5
        pathLayer = drawingLayer
        self.scrollView.layer.addSublayer(pathLayer!)
    }
    
    // MARK: - Vision
    
    /// - Tag: PerformRequests
    fileprivate func performVisionRequest(image: CGImage, orientation: CGImagePropertyOrientation) {
        
        // Fetch desired requests based on switch status.
        let requests = createVisionRequests()
        // Create a request handler.
        let imageRequestHandler = VNImageRequestHandler(cgImage: image,
                                                        orientation: orientation,
                                                        options: [:])
        
        // Send the requests to the request handler.
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try imageRequestHandler.perform(requests)
            } catch let error as NSError {
                debugPrint("Failed to perform image request: \(error)")
                self.presentAlert("Image Request Failed", error: error)
                return
            }
        }
    }
    
    /// - Tag: CreateRequests
    fileprivate func createVisionRequests() -> [VNRequest] {
        
        // Create an array to collect all desired requests.
        var requests: [VNRequest] = []
        
        // Create & include a request if and only if switch is ON.
        requests.append(self.rectangleDetectionRequest)
        // Break rectangle & face landmark detection into 2 stages to have more fluid feedback in UI.
        requests.append(self.faceDetectionRequest)
        requests.append(self.faceLandmarkRequest)
        requests.append(self.textDetectionRequest)
        requests.append(self.barcodeDetectionRequest)
        
        // Return grouped requests as a single array.
        return requests
    }
    
    fileprivate func handleDetectedRectangles(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            self.presentAlert("Rectangle Detection Error", error: nsError)
            return
        }
        // Since handlers are executing on a background thread, explicitly send draw calls to the main thread.
        DispatchQueue.main.async {
            guard let drawLayer = self.pathLayer,
                let results = request?.results as? [VNRectangleObservation] else {
                    return
            }
            self.draw(rectangles: results, onImageWithBounds: drawLayer.bounds)
            drawLayer.setNeedsDisplay()
        }
    }
    
    fileprivate func handleDetectedFaces(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            self.presentAlert("Face Detection Error", error: nsError)
            return
        }
        // Perform drawing on the main thread.
        DispatchQueue.main.async {
            guard let drawLayer = self.pathLayer,
                let results = request?.results as? [VNFaceObservation] else {
                    return
            }
            self.draw(faces: results, onImageWithBounds: drawLayer.bounds)
            drawLayer.setNeedsDisplay()
        }
    }
    
    fileprivate func handleDetectedFaceLandmarks(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            self.presentAlert("Face Landmark Detection Error", error: nsError)
            return
        }
        // Perform drawing on the main thread.
        DispatchQueue.main.async {
            guard let drawLayer = self.pathLayer,
                let results = request?.results as? [VNFaceObservation] else {
                    return
            }
            self.drawFeatures(onFaces: results, onImageWithBounds: drawLayer.bounds)
            drawLayer.setNeedsDisplay()
        }
    }
    
    fileprivate func handleDetectedText(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            self.presentAlert("Text Detection Error", error: nsError)
            return
        }
        // Perform drawing on the main thread.
        DispatchQueue.main.async {
            guard let drawLayer = self.pathLayer,
                let results = request?.results as? [VNTextObservation] else {
                    return
            }
            self.draw(text: results, onImageWithBounds: drawLayer.bounds)
            drawLayer.setNeedsDisplay()
        }
    }
    
    fileprivate func handleDetectedBarcodes(request: VNRequest?, error: Error?) {
        if let nsError = error as NSError? {
            self.presentAlert("Barcode Detection Error", error: nsError)
            return
        }
        // Perform drawing on the main thread.
        DispatchQueue.main.async {
            guard let drawLayer = self.pathLayer,
                let results = request?.results as? [VNBarcodeObservation] else {
                    return
            }
            self.draw(barcodes: results, onImageWithBounds: drawLayer.bounds)
            drawLayer.setNeedsDisplay()
        }
    }
    
    /// - Tag: ConfigureCompletionHandler
    lazy var rectangleDetectionRequest: VNDetectRectanglesRequest = {
        let rectDetectRequest = VNDetectRectanglesRequest(completionHandler: self.handleDetectedRectangles)
        // Customize & configure the request to detect only certain rectangles.
        rectDetectRequest.maximumObservations = 8 // Vision currently supports up to 16.
        rectDetectRequest.minimumConfidence = 0.6 // Be confident.
        rectDetectRequest.minimumAspectRatio = 0.3 // height / width
        return rectDetectRequest
    }()
    
    lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleDetectedFaces)
    lazy var faceLandmarkRequest = VNDetectFaceLandmarksRequest(completionHandler: self.handleDetectedFaceLandmarks)
    
    lazy var textDetectionRequest: VNDetectTextRectanglesRequest = {
        let textDetectRequest = VNDetectTextRectanglesRequest(completionHandler: self.handleDetectedText)
        // Tell Vision to report bounding box around each character.
        textDetectRequest.reportCharacterBoxes = true
        return textDetectRequest
    }()
    
    lazy var barcodeDetectionRequest: VNDetectBarcodesRequest = {
        let barcodeDetectRequest = VNDetectBarcodesRequest(completionHandler: self.handleDetectedBarcodes)
        // Restrict detection to most common symbologies.
        barcodeDetectRequest.symbologies = [.QR, .Aztec, .UPCE]
        return barcodeDetectRequest
    }()
    
    // MARK: - Path-Drawing
    
    fileprivate func boundingBox(forRegionOfInterest: CGRect, withinImageBounds bounds: CGRect) -> CGRect {
        
        let imageWidth = bounds.width
        let imageHeight = bounds.height
        
        // Begin with input rect.
        var rect = forRegionOfInterest
        
        // Reposition origin.
        rect.origin.x *= imageWidth
        rect.origin.x += bounds.origin.x
        rect.origin.y = (1 - rect.origin.y) * imageHeight + bounds.origin.y
        
        // Rescale normalized coordinates.
        rect.size.width *= imageWidth
        rect.size.height *= imageHeight
        
        return rect
    }
    
    fileprivate func shapeLayer(color: UIColor, frame: CGRect) -> CAShapeLayer {
        // Create a new layer.
        let layer = CAShapeLayer()
        
        // Configure layer's appearance.
        layer.fillColor = nil // No fill to show boxed object
        layer.shadowOpacity = 0
        layer.shadowRadius = 0
        layer.borderWidth = 2
        
        // Vary the line color according to input.
        layer.borderColor = color.cgColor
        
        // Locate the layer.
        layer.anchorPoint = .zero
        layer.frame = frame
        layer.masksToBounds = true
        
        // Transform the layer to have same coordinate system as the imageView underneath it.
        layer.transform = CATransform3DMakeScale(1, -1, 1)
        
        return layer
    }
    
    // Rectangles are BLUE.
    fileprivate func draw(rectangles: [VNRectangleObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        for observation in rectangles {
            let rectBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
            let rectLayer = shapeLayer(color: .blue, frame: rectBox)
            
            // Add to pathLayer on top of image.
            pathLayer?.addSublayer(rectLayer)
        }
        CATransaction.commit()
    }
    
    // Faces are YELLOW.
    /// - Tag: DrawBoundingBox
    fileprivate func draw(faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        for observation in faces {
            let faceBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
            let faceLayer = shapeLayer(color: .yellow, frame: faceBox)
            
            // Add to pathLayer on top of image.
            pathLayer?.addSublayer(faceLayer)
        }
        CATransaction.commit()
    }
    
    // Facial landmarks are GREEN.
    fileprivate func drawFeatures(onFaces faces: [VNFaceObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        for faceObservation in faces {
            let faceBounds = boundingBox(forRegionOfInterest: faceObservation.boundingBox, withinImageBounds: bounds)
            guard let landmarks = faceObservation.landmarks else {
                continue
            }
            
            // Iterate through landmarks detected on the current face.
            let landmarkLayer = CAShapeLayer()
            let landmarkPath = CGMutablePath()
            let affineTransform = CGAffineTransform(scaleX: faceBounds.size.width, y: faceBounds.size.height)
            
            // Treat eyebrows and lines as open-ended regions when drawing paths.
            let openLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
                landmarks.leftEyebrow,
                landmarks.rightEyebrow,
                landmarks.faceContour,
                landmarks.noseCrest,
                landmarks.medianLine
            ]
            
            // Draw eyes, lips, and nose as closed regions.
            let closedLandmarkRegions = [
                landmarks.leftEye,
                landmarks.rightEye,
                landmarks.outerLips,
                landmarks.innerLips,
                landmarks.nose
                ].compactMap { $0 } // Filter out missing regions.
            
            // Draw paths for the open regions.
            for openLandmarkRegion in openLandmarkRegions where openLandmarkRegion != nil {
                landmarkPath.addPoints(in: openLandmarkRegion!,
                                       applying: affineTransform,
                                       closingWhenComplete: false)
            }
            
            // Draw paths for the closed regions.
            for closedLandmarkRegion in closedLandmarkRegions {
                landmarkPath.addPoints(in: closedLandmarkRegion,
                                       applying: affineTransform,
                                       closingWhenComplete: true)
            }
            
            // Format the path's appearance: color, thickness, shadow.
            landmarkLayer.path = landmarkPath
            landmarkLayer.lineWidth = 2
            landmarkLayer.strokeColor = UIColor.green.cgColor
            landmarkLayer.fillColor = nil
            landmarkLayer.shadowOpacity = 0.75
            landmarkLayer.shadowRadius = 4
            
            // Locate the path in the parent coordinate system.
            landmarkLayer.anchorPoint = .zero
            landmarkLayer.frame = faceBounds
            landmarkLayer.transform = CATransform3DMakeScale(1, -1, 1)
            
            // Add to pathLayer on top of image.
            pathLayer?.addSublayer(landmarkLayer)
        }
        CATransaction.commit()
    }
    
    // Lines of text are RED.  Individual characters are PURPLE.
    fileprivate func draw(text: [VNTextObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        for wordObservation in text {
            let wordBox = boundingBox(forRegionOfInterest: wordObservation.boundingBox, withinImageBounds: bounds)
            let wordLayer = shapeLayer(color: .red, frame: wordBox)
            
            // Add to pathLayer on top of image.
            pathLayer?.addSublayer(wordLayer)
            
            // Iterate through each character within the word and draw its box.
            guard let charBoxes = wordObservation.characterBoxes else {
                continue
            }
            for charObservation in charBoxes {
                let charBox = boundingBox(forRegionOfInterest: charObservation.boundingBox, withinImageBounds: bounds)
                let charLayer = shapeLayer(color: .purple, frame: charBox)
                charLayer.borderWidth = 1
                
                // Add to pathLayer on top of image.
                pathLayer?.addSublayer(charLayer)
            }
        }
        CATransaction.commit()
    }
    
    // Barcodes are ORANGE.
    fileprivate func draw(barcodes: [VNBarcodeObservation], onImageWithBounds bounds: CGRect) {
        CATransaction.begin()
        for observation in barcodes {
            let barcodeBox = boundingBox(forRegionOfInterest: observation.boundingBox, withinImageBounds: bounds)
            let barcodeLayer = shapeLayer(color: .orange, frame: barcodeBox)
            
            // Add to pathLayer on top of image.
            pathLayer?.addSublayer(barcodeLayer)
        }
        CATransaction.commit()
    }
}

private extension CGMutablePath {
    // Helper function to add lines to a path.
    func addPoints(in landmarkRegion: VNFaceLandmarkRegion2D,
                   applying affineTransform: CGAffineTransform,
                   closingWhenComplete closePath: Bool) {
        let pointCount = landmarkRegion.pointCount
        
        // Draw line if and only if path contains multiple points.
        guard pointCount > 1 else {
            return
        }
        self.addLines(between: landmarkRegion.normalizedPoints, transform: affineTransform)
        
        if closePath {
            self.closeSubpath()
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ uiImageOrientation: UIImage.Orientation) {
        switch uiImageOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        default: self = .up
        }
    }
}

