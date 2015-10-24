//
//  ViewController.swift
//  Canigoo
//
//  Created by Benjamin McMurrich on 12/10/2015.
//  Copyright (c) 2015 @ben_mcm. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer

// KVO contexts
private var PlayerObserverContext = 0

// KVO player
private let PlayerReadyForDisplay = "readyForDisplay"


class RadioViewController: UIViewController {
    
    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var toggleButtonView: UIView!
    @IBOutlet weak var volumeView: MPVolumeView!
    
    @IBOutlet weak var showView: UIView!
    @IBOutlet weak var onAirView: UIView!
    @IBOutlet weak var showScheduleLabel: UILabel!
    @IBOutlet weak var showNameLabel: UILabel!
    @IBOutlet weak var showDescriptionLabel: UILabel!

    @IBOutlet weak var currentTrackLabel: UILabel!
    
    //private var player = AVPlayer(URL: NSURL(string: "http://canigoo.com:8000/canigoo_002_128")!)
    private var player:AVPlayer!
    private var currentlyPlaying = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.showView.layer.cornerRadius = 5
        self.showView.alpha = 0
        self.onAirView.layer.cornerRadius = 5
        self.onAirView.layer.borderColor = UIColor(red: 214.0/255, green: 186.0/255, blue: 37.0/255, alpha: 1).CGColor
        self.onAirView.layer.borderWidth = 1
        self.toggleButtonView.layer.cornerRadius = 32
        
        if NSClassFromString("MPNowPlayingInfoCenter") != nil {
            
            let image:UIImage = UIImage(named: "backgroundPlaceholder")!
            let albumArt = MPMediaItemArtwork(image: image)
            let songInfo = [
                MPMediaItemPropertyTitle: "Canigoo Radio",
                MPMediaItemPropertyArtist: "www.canigoo.com",
                MPMediaItemPropertyArtwork: albumArt
            ]
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = songInfo
        }
        
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, withOptions: [])
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        volumeView.tintColor = UIColor(red: 214.0/255, green: 186.0/255, blue: 37.0/255, alpha: 1)
        
        refreshInfo()
        
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func toggleButtonAction(sender: AnyObject) {
        if self.currentlyPlaying {
            pauseRadio()
        } else {
            playRadio()
        }
    }
    
    func playRadio() {
        let url = "http://canigoo.com:8000/canigoo_002_128"
        
        let playerItem = AVPlayerItem(URL:NSURL(string:url)!)
        player = AVPlayer(playerItem:playerItem)
        player.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.New, context:nil)
        
        toggleButton.setImage(UIImage(named: "pauseBtn")!, forState: UIControlState.Normal)
        player.play()
        self.currentlyPlaying = true
        
        refreshInfo()
    }
    
    func pauseRadio() {
        player.pause()
        player.removeObserver(self, forKeyPath: "status")
        self.currentlyPlaying = false
        toggleButton.setImage(UIImage(named: "playBtn")!, forState: UIControlState.Normal)
        player = nil
    }
    
    func refreshInfo() {
        
        let jsonUrl = "http://radio.canigoo.com/api/live-info-v2"
        
        let session = NSURLSession.sharedSession()
        let shotsUrl = NSURL(string: jsonUrl)
        
        let task = session.dataTaskWithURL(shotsUrl!) {
            (data, response, error) -> Void in
            
            if !(error != nil) {
                let json = JSON(data: data!)
                
                print(json)
                
                dispatch_async(dispatch_get_main_queue()) {
                    
                    if let currentShow = json["shows"]["current"].dictionary {
                        self.showNameLabel.text = currentShow["name"]!.string
                        self.showDescriptionLabel.text = currentShow["description"]!.string
                        
                        if let starts = currentShow["starts"]!.string {
                            if let ends = currentShow["ends"]!.string {
                                
                                let dateFormatter = NSDateFormatter()
                                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:SS"
                                let startDate = dateFormatter.dateFromString(starts)
                                let endDate = dateFormatter.dateFromString(ends)
                                
                                dateFormatter.dateFormat = "h:mm a"
                                let startTime = dateFormatter.stringFromDate(startDate!)
                                let endTime = dateFormatter.stringFromDate(endDate!)
                                
                                self.showScheduleLabel.text = "from " + startTime + " to " + endTime
                            }
                        }
                    }
                    
                    if let currentTrackEnds = json["tracks"]["current"]["ends"].string {
                        let dateFormatter = NSDateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:SS"
                        let endDate = dateFormatter.dateFromString(currentTrackEnds)
                        let elapsedTime = endDate!.timeIntervalSinceDate(NSDate())
                        print(elapsedTime)
                        NSTimer.scheduledTimerWithTimeInterval(elapsedTime + 3, target: self, selector: "refreshInfo", userInfo: nil, repeats: false)
                    }
                    
                    
                    if let currentTrackName = json["tracks"]["current"]["name"].string {
                        self.currentTrackLabel.text = currentTrackName
                        
                        if NSClassFromString("MPNowPlayingInfoCenter") != nil {
                            
                            let image:UIImage = UIImage(named: "backgroundPlaceholder")!
                            let albumArt = MPMediaItemArtwork(image: image)
                            let songInfo = [
                                MPMediaItemPropertyTitle: currentTrackName,
                                MPMediaItemPropertyArtist: "www.canigoo.com",
                                MPMediaItemPropertyArtwork: albumArt
                            ]
                            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = songInfo
                        }
                    }
                    
                    UIView.animateWithDuration(0.5, animations: { () -> Void in
                        self.showView.alpha = 1
                    })
                    
                }
            }
            
        }
        
        task.resume()
    }
    
    // MARK: KVO
    
    override internal func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        
        if let change = change as? [String: Int]
        {
            let status = change[NSKeyValueChangeNewKey]!
            switch (status) {
            case AVPlayerStatus.ReadyToPlay.rawValue:
                
                //toggleButton.setImage(UIImage(named: "pauseBtn")!, forState: UIControlState.Normal)
                //player.play()
                self.currentlyPlaying = true
                
            case AVPlayerStatus.Failed.rawValue:
                print("Failed to stream audio")
                
            default:
                true
            }
            
        }
        
    }

}

