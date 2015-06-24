//
//  ViewController.swift
//  RACamera
//
//  Created by Samuel Yuli Bai on 5/26/15.
//  Copyright (c) 2015 RedApricot. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var videoFilter : RAVideoFilter?
    var detector: CIDetector?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create the filter
        
        videoFilter = RAVideoFilter(superview: view, applyFilterCallback: nil)
        videoFilter?.setCameraPosition(0)
 //       videoFilter?.applyFilter = {image in  return self.videoFilter?.mergeImage(image)}
 //       videoFilter?.applyFilter = videoFilter?.fblur(1.0)
        videoFilter?.topImage = UIImage(named: "bee")?.imageRotatedByDegrees(-90, flip: false)
        videoFilter?.settingFilter = videoFilter?.fblur(5.0)
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
        videoFilter?.captureImage()
    }
    
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.locationInView(self.view)
            videoFilter?.touchLocation = location
//            videoFilter?.applyFilter = videoFilter?.fmergeAtPoint(UIImage(named: "bee")!, topLoc: location)
            videoFilter?.updateApplyFilter()
            print(location)
        }
        super.touchesBegan(touches, withEvent:event)
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        if UIDevice.currentDevice().orientation.isLandscape.boolValue {
            print("landscape")
        } else {
            print("portraight")
        }
    }

}

