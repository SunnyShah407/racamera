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
        videoFilter?.setCameraPosition(0)
        videoFilter?.applyFilter = {image in  return self.videoFilter?.mergeImage(image)}
        videoFilter?.startFiltering()
        
    }
    
    
    @IBAction func switchCamera(sender: AnyObject) {
        if let _ = videoFilter {
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
        videoFilter?.captureImageWithFilter()
    }
    
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.locationInView(self.view)
            videoFilter?.touchLocation = location
            print(location)
        }
        super.touchesBegan(touches, withEvent:event)
    }
}

