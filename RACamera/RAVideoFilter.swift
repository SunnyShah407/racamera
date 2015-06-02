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
        var error: NSError?
        for oldDevice in avSession?.inputs as! [AVCaptureDeviceInput] {
            avSession?.removeInput(oldDevice)
        }
        let input = AVCaptureDeviceInput(device: self.device, error: &error)
        avSession?.addInput(input)
    }
    
    func createAVSession() -> AVCaptureSession {
        // 选择一个输入设备
        var error: NSError?
        let input = AVCaptureDeviceInput(device: self.device, error: &error)
    
        // Start out with low quality
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetMedium
    
        // Vedio Output
    
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [ kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA]
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
    
    
    func caputrePhoto() -> UIImage? {
        var resImage : UIImage?
        if let videoConnection = self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        {
            self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(videoConnection)
                {
                    (imageSampleBuffer : CMSampleBuffer?, error: NSError?) -> Void in
                    
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
   
    //TODO: 照相功能
    func captureImage() -> UIImage {
        var resImage : UIImage!
        let connection = self.stillImageOutput.connectionWithMediaType(AVMediaTypeVideo)
        // 将视频的旋转与设备同步
        connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.currentDevice().orientation.rawValue)!
        
        self.stillImageOutput.captureStillImageAsynchronouslyFromConnection(connection) {
            (imageDataSampleBuffer, error) -> Void in
            
            if error == nil {
                
                // 如果使用 session .Photo 预设，或者在设备输出设置中明确进行了设置
                // 我们就能获得已经压缩为JPEG的数据
                
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                
                // 样本缓冲区也包含元数据，我们甚至可以按需修改它
                
                let metadata:NSDictionary = CMCopyDictionaryOfAttachments(nil, imageDataSampleBuffer, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)).takeUnretainedValue()
                
                if let image = UIImage(data: imageData) {
                    // 保存图片，或者做些其他想做的事情
                    resImage = image
                }
            }
            else {
                NSLog("error while capturing still image: \(error)")
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