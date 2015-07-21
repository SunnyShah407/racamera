//
//  RACamera.swift
//  RACamera
//
//  Created by Samuel Yuli Bai on 7/20/15.
//  Copyright © 2015 RedApricot. All rights reserved.
//

import Foundation
import AVFoundation

//TODO: 照相功能
func captureImage(){
    if let connection = stillImageOutput.connectionWithMediaType(AVMediaTypeVideo) {
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