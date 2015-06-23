//
//  CoreImageFilter.swift
//  RACamera
//
//  Created by Samuel Yuli Bai on 5/26/15.
//  Copyright (c) 2015 RedApricot. All rights reserved.
//

import UIKit
import GLKit
import AVFoundation
import CoreMedia
import CoreImage
import OpenGLES
import QuartzCore

typealias Parameters = Dictionary<String, AnyObject>
typealias Filter = CIImage -> CIImage?

infix operator >|> { associativity left }

func >|> (filter1: Filter, filter2: Filter) -> Filter {
    return { img in filter2(filter1(img)!) }
}

class RAVideoFilter: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var applyFilter: ((CIImage) -> CIImage?)?       //滤镜方法
    var device : AVCaptureDevice!   //摄像头位置 0: Front  1: Back
    var videoDisplayView: GLKView!
    var videoDisplayViewBounds: CGRect!
    var renderContext: CIContext!
    var avSession: AVCaptureSession?
    var sessionQueue: dispatch_queue_t!
    var detector: CIDetector?
    var videoInput: AVCaptureDeviceInput!
    var videoOutput:    AVCaptureVideoDataOutput!
    var stillImageOutput: AVCaptureStillImageOutput!
    var touchLocation: CGPoint?
  
    init(superview: UIView, applyFilterCallback: ((CIImage) -> CIImage?)?) {
        self.applyFilter = applyFilterCallback
        videoDisplayView = GLKView(frame: superview.bounds, context: EAGLContext(API: .OpenGLES2)!)
        videoDisplayView.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
        videoDisplayView.frame = superview.bounds
        superview.addSubview(videoDisplayView)
        superview.sendSubviewToBack(videoDisplayView)
    
        renderContext = CIContext(EAGLContext: videoDisplayView.context)
        sessionQueue = dispatch_queue_create("AVSessionQueue", DISPATCH_QUEUE_SERIAL)
    
        videoDisplayView.bindDrawable()
        videoDisplayViewBounds = CGRect(x: 0, y: 0, width: videoDisplayView.drawableWidth, height: videoDisplayView.drawableHeight)
    }
  
    deinit {
        stopFiltering()
    }
  
    func startFiltering() {
        if avSession == nil {
            avSession = createAVSession()
        }
        avSession?.startRunning()
    }
  
    func stopFiltering() {
        avSession?.stopRunning()
    }
    //TODO: 修改下前后相机参数的设定
    func setCameraPosition(position: Int8) {
        let avalableCameraDevices  = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for ldevice in avalableCameraDevices as! [AVCaptureDevice] {
            if position == 0 && ldevice.position == .Front {
                self.device = ldevice
            }
            else if ldevice.position == .Back {
                self.device = ldevice
            }
        }
    }
  
    // 刷新session设置
    func updateAVSession(){
        for oldDevice in avSession?.inputs as! [AVCaptureDeviceInput] {
            avSession?.removeInput(oldDevice)
        }
        let input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: self.device)
        } catch  _ as NSError {
            input = nil
        }
        avSession?.addInput(input)
    }
    
    func createAVSession() -> AVCaptureSession {
        // set input device

        let input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: self.device)
        } catch _ as NSError {
            input = nil
        }
    
        // Start out with low quality
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetMedium
    
        // Vedio Output
    
        videoOutput = AVCaptureVideoDataOutput()
//        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        
        // Still image output
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        
        
        // Join it all together
        session.addInput(input)
        session.addOutput(videoOutput)
        session.addOutput(stillImageOutput)

        return session
    }
    
    
    //TODO: 照相功能
    func captureImage(){
        if let connection = stillImageOutput?.connectionWithMediaType(AVMediaTypeVideo) {
            stillImageOutput?.captureStillImageAsynchronouslyFromConnection(connection)
                {
                    (imageSampleBuffer : CMSampleBuffer!, _) in
                    
                    let imageDataJpeg = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageSampleBuffer)
                    let pickedImage: UIImage = UIImage(data: imageDataJpeg)!
                    let ciContext = CIContext(options: nil)
                    let resImage = self.applyFilter!(CIImage(image: pickedImage)!)
                    let cgImage = ciContext.createCGImage(resImage!, fromRect: (CIImage(image:pickedImage)?.extent)!)
                    let uiImage = UIImage(CGImage: cgImage)
                    print(uiImage.size)
                    UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            }
        }
        else {
            print("error on connect")
        }
    }
    
    // Filter
    func ftest() -> Filter {
        let topImage = UIImage(named: "bee")
        return self.fblur(5.0) >|> self.fmerge(CIImage(image: topImage!)!)
    }
    
    func fmergeAtPoint(inputImage: UIImage, topLoc: CGPoint) -> Filter {
        UIGraphicsBeginImageContextWithOptions(inputImage.size, false, 0)
        inputImage.drawAtPoint(topLoc)
        let im = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        let ciim = CIImage(image: im)
        return {
            image in
            let filter = CIFilter(name: "CIDarkenBlendMode")
            filter!.setValue(image,forKey: kCIInputBackgroundImageKey)
            filter!.setValue(ciim, forKey: kCIInputImageKey)
            return filter!.outputImage
        }
    }
    
    func fmerge(topImage:CIImage) -> Filter {
        return {
            image in
            let filter = CIFilter(name: "CIDarkenBlendMode")
            filter!.setValue(image,forKey: kCIInputBackgroundImageKey)
            filter!.setValue(topImage, forKey: kCIInputImageKey)
            return filter!.outputImage
        }
    }

    func fblur(radius: Double) -> Filter {
        return {
            image in
            let parameters = [kCIInputRadiusKey: radius, kCIInputImageKey: image]
            let filter = CIFilter(name:"CIGaussianBlur", withInputParameters:parameters)
            return filter!.outputImage
        }
    }
    
    //TODO: 文字滤镜 - 添加文字overlay
    //TODO:
    
    //MARK: <AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
    
        // Need to shimmy this through type-hell
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        // Force the type change - pass through opaque buffer
        let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer!).toOpaque()
        let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
    
        let sourceImage = CIImage(CVPixelBuffer: pixelBuffer, options: nil)
    
        // Do some detection on the image
        let detectionResult = applyFilter?(sourceImage)
        var outputImage = sourceImage
        if detectionResult != nil {
            outputImage = detectionResult!
        }
    
        // Do some clipping
        var drawFrame = outputImage.extent
        let imageAR = drawFrame.width / drawFrame.height
        let viewAR = videoDisplayViewBounds.width / videoDisplayViewBounds.height
        if imageAR > viewAR {
            drawFrame.origin.x += (drawFrame.width - drawFrame.height * viewAR) / 2.0
            drawFrame.size.width = drawFrame.height / viewAR
        } else {
            drawFrame.origin.y += (drawFrame.height - drawFrame.width / viewAR) / 2.0
            drawFrame.size.height = drawFrame.width / viewAR
        }
    
        videoDisplayView.bindDrawable()
        if videoDisplayView.context != EAGLContext.currentContext() {
            EAGLContext.setCurrentContext(videoDisplayView.context)
        }
    
        // clear eagl view to grey
        glClearColor(0.5, 0.5, 0.5, 1.0);
        glClear(0x00004000)
        
        // set the blend mode to "source over" so that CI will use that
        glEnable(0x0BE2);
        glBlendFunc(1, 0x0303);
        
        renderContext.drawImage(outputImage, inRect: videoDisplayViewBounds, fromRect: drawFrame)
        videoDisplayView.display()
        
        }
}