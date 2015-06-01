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

class CoreImageVideoFilter: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var applyFilter: ((CIImage) -> CIImage?)?
    var videoDisplayView: GLKView!
    var videoDisplayViewBounds: CGRect!
    var renderContext: CIContext!
  
    var avSession: AVCaptureSession?
    var sessionQueue: dispatch_queue_t!
  
    var detector: CIDetector?
    
    var stillImageOutput: AVCaptureStillImageOutput!
    var saveImage : UIImage?
  
    init(superview: UIView, applyFilterCallback: ((CIImage) -> CIImage?)?) {
        self.applyFilter = applyFilterCallback
        videoDisplayView = GLKView(frame: superview.bounds, context: EAGLContext(API: .OpenGLES2))
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
        // Create a session if we don't already have one
        if avSession == nil {
            avSession = createAVSession()
        }
    
        // And kick it off
        avSession?.startRunning()
    }
  
    func stopFiltering() {
        // Stop the av session
        avSession?.stopRunning()
    }
  
    func createAVSession() -> AVCaptureSession {
        // 选择一个输入设备
        var backCamera:AVCaptureDevice?
        var frontCamera:AVCaptureDevice?
    
        let availableCameraDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for device in availableCameraDevices as! [AVCaptureDevice] {
            if device.position == .Back {
                backCamera = device
            }
            else if device.position == .Front {
                frontCamera = device
            }
        }
    
        // 设置默认设备为后置摄像头
        let device = backCamera
        var error: NSError?
        let input = AVCaptureDeviceInput(device: device, error: &error)
    
        // Start out with low quality
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetMedium
    
        // Output
        let videoOutput = AVCaptureVideoDataOutput()
    
        videoOutput.videoSettings = [ kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
    
        // Join it all together
        session.addInput(input)
        session.addOutput(videoOutput)

        return session
    }
    
    
    func caputrePhoto() -> UIImage? {
        var resImage : UIImage?
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        if (avSession?.canAddOutput(stillImageOutput) != nil){
            avSession?.addOutput(stillImageOutput)
        }
        if let videoConnection = stillImageOutput?.connectionWithMediaType(AVMediaTypeVideo)
        {
            stillImageOutput?.captureStillImageAsynchronouslyFromConnection(videoConnection)
                {
                    (imageSampleBuffer : CMSampleBuffer!, _) in
                    
                    let imageDataJpeg = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageSampleBuffer)
                    var pickedImage: CIImage = CIImage(data: imageDataJpeg)!
                    let detecitionResult = self.applyFilter!(pickedImage)
                    resImage = UIImage(CIImage: pickedImage)
                    if detecitionResult != nil {
                        resImage = UIImage(CIImage: detecitionResult!)
                    }
            }
        }
        return resImage
    }
    
    func takePhoto() -> UIImage? {
        var resImage : UIImage?
        let connection = self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.currentDevice().orientation.rawValue)!
        self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(connection) {
            (imageDataSampleBuffer, error) -> Void in
            if error == nil {
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                let metadata:NSDictionary = CMCopyDictionaryOfAttachments(nil, imageDataSampleBuffer, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)).takeRetainedValue()
                if let image = UIImage(data:imageData){
                    resImage = image
                }
            }
            else {
                println("error while capturing still image : \(error)")
            }
        }
        return resImage
    }
    
    
  
    //MARK: <AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
    
        // Need to shimmy this through type-hell
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        // Force the type change - pass through opaque buffer
        let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer).toOpaque()
        let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
    
        let sourceImage = CIImage(CVPixelBuffer: pixelBuffer, options: nil)
    
        // Do some detection on the image
        let detectionResult = applyFilter?(sourceImage)
        var outputImage = sourceImage
        if detectionResult != nil {
            outputImage = detectionResult!
        }
    
        // Do some clipping
        var drawFrame = outputImage.extent()
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