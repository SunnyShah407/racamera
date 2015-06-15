//
//  ViewController.swift
//  RACamera
//
//  Created by Samuel Yuli Bai on 5/26/15.
//  Copyright (c) 2015 RedApricot. All rights reserved.
//

import UIKit

typealias Filter = CIImage -> CIImage

class ViewController: UIViewController {

    var videoFilter : RAVideoFilter?
    var detector: CIDetector?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create the filter
        
        videoFilter = RAVideoFilter(superview: view, applyFilterCallback: nil)
//        detector = prepareRectangleDetector()
        
//        videoFilter?.applyFilter = {image in  return self.performRectangleDetection(image)}
        videoFilter?.setCameraPosition(0)
//        videoFilter?.applyFilter = {image in  return self.performFilter(image)}
        videoFilter?.applyFilter = {image in  return self.mergeImage(image)}
        videoFilter?.startFiltering()
        
    }
    
    
    @IBAction func switchCamera(sender: AnyObject) {
        if let vedioFilter = videoFilter {
            videoFilter?.stopFiltering()
            switch sender.selectedSegmentIndex {
            case 0 :
                videoFilter?.setCameraPosition(0)
            case 1:
                videoFilter?.setCameraPosition(1)
            default:
                videoFilter?.setCameraPosition(1)
            }
            videoFilter?.updateAVSession()
            videoFilter?.startFiltering()
        }
    }
    
    @IBAction func takePhoto(sender: UIButton) {
        if let savePhoto = videoFilter?.captureImage(){
            UIImageWriteToSavedPhotosAlbum(savePhoto, nil, nil, nil) 
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    func mergeImage(image:CIImage) -> CIImage? {
        var resultImage: CIImage?
        let topImage = UIImage(named:"bee")
        let filter = CIFilter(name: "CIDarkenBlendMode")
        filter.setValue(image,forKey: kCIInputBackgroundImageKey)
        filter.setValue(CIImage(image: topImage), forKey: kCIInputImageKey)
        return filter.outputImage
    }
    //MARK: Utility methods
    
    
    func performFilter(image: CIImage) -> CIImage? {
        var resultImage: CIImage?
        let filter = CIFilter(name:"CISepiaTone")
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(0.5, forKey: kCIInputIntensityKey)
        resultImage = filter.outputImage
        return resultImage
    }
    
    func performRectangleDetection(image: CIImage) -> CIImage? {
        var resultImage: CIImage?
        if let detector = detector {
            // Get the detections
            let features = detector.featuresInImage(image)
            for feature in features as! [CIRectangleFeature] {
                resultImage = drawHighlightOverlayForPoints(image, topLeft: feature.topLeft, topRight: feature.topRight,
                    bottomLeft: feature.bottomLeft, bottomRight: feature.bottomRight)
            }
        }
        return resultImage
    }
    
    func performQRCodeDetection(image: CIImage) -> (outImage: CIImage?, decode: String) {
        var resultImage: CIImage?
        var decode = ""
        if let detector = detector {
            let features = detector.featuresInImage(image)
            for feature in features as! [CIQRCodeFeature] {
                resultImage = drawHighlightOverlayForPoints(image, topLeft: feature.topLeft, topRight: feature.topRight,
                    bottomLeft: feature.bottomLeft, bottomRight: feature.bottomRight)
                decode = feature.messageString
            }
        }
        return (resultImage, decode)
    }
    
    func prepareRectangleDetector() -> CIDetector {
        let options: [String: AnyObject] = [CIDetectorAccuracy: CIDetectorAccuracyHigh, CIDetectorAspectRatio: 1.0]
        return CIDetector(ofType: CIDetectorTypeRectangle, context: nil, options: options)
    }
    
    func prepareQRCodeDetector() -> CIDetector {
        let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        return CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: options)
    }
    
    func drawHighlightOverlayForPoints(image: CIImage, topLeft: CGPoint, topRight: CGPoint,
        bottomLeft: CGPoint, bottomRight: CGPoint) -> CIImage {
            var overlay = CIImage(color: CIColor(red: 1.0, green: 0, blue: 0, alpha: 0.5))
            overlay = overlay.imageByCroppingToRect(image.extent)
            overlay = overlay.imageByApplyingFilter("CIPerspectiveTransformWithExtent",
                withInputParameters: [
                    "inputExtent": CIVector(CGRect: image.extent),
                    "inputTopLeft": CIVector(CGPoint: topLeft),
                    "inputTopRight": CIVector(CGPoint: topRight),
                    "inputBottomLeft": CIVector(CGPoint: bottomLeft),
                    "inputBottomRight": CIVector(CGPoint: bottomRight)
                ])
            return overlay.imageByCompositingOverImage(image)
    }
}

