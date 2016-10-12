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
    fileprivate var player:AVPlayer!
    fileprivate var currentlyPlaying = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.showView.layer.cornerRadius = 5
        self.showView.alpha = 0
        self.onAirView.layer.cornerRadius = 5
        self.onAirView.layer.borderColor = UIColor(red: 214.0/255, green: 186.0/255, blue: 37.0/255, alpha: 1).cgColor
        self.onAirView.layer.borderWidth = 1
        self.toggleButtonView.layer.cornerRadius = 32
        
        if NSClassFromString("MPNowPlayingInfoCenter") != nil {
            
            let image:UIImage = UIImage(named: "backgroundPlaceholder")!
            let albumArt = MPMediaItemArtwork(image: image)
            let songInfo = [
                MPMediaItemPropertyTitle: "Canigoo Radio",
                MPMediaItemPropertyArtist: "www.canigoo.com",
                MPMediaItemPropertyArtwork: albumArt
            ] as [String : Any]
            MPNowPlayingInfoCenter.default().nowPlayingInfo = songInfo
        }
        
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: [])
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        volumeView.tintColor = UIColor(red: 214.0/255, green: 186.0/255, blue: 37.0/255, alpha: 1)
        
        refreshInfo()
        
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func toggleButtonAction(_ sender: AnyObject) {
        if self.currentlyPlaying {
            pauseRadio()
        } else {
            playRadio()
        }
    }
    
    func playRadio() {
        let url = "http://canigoo.com:8000/canigoo_002_128"
        
        let playerItem = AVPlayerItem(url:URL(string:url)!)
        player = AVPlayer(playerItem:playerItem)
        player.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context:nil)
        
        toggleButton.setImage(UIImage(named: "pauseBtn")!, for: UIControlState())
        player.play()
        self.currentlyPlaying = true
        
        refreshInfo()
    }
    
    func pauseRadio() {
        player.pause()
        player.removeObserver(self, forKeyPath: "status")
        self.currentlyPlaying = false
        toggleButton.setImage(UIImage(named: "playBtn")!, for: UIControlState())
        player = nil
    }
    
    func refreshInfo() {
        
        let jsonUrl = "http://radio.canigoo.com/api/live-info-v2"
        
        let session = URLSession.shared
        let shotsUrl = URL(string: jsonUrl)
        
        let task = session.dataTask(with: shotsUrl!, completionHandler: {
            (data, response, error) -> Void in
            
            if !(error != nil) {
                let json = JSON(data: data!)
                
                print(json)
                
                DispatchQueue.main.async {
                    
                    if let currentShow = json["shows"]["current"].dictionary {
                        self.showNameLabel.text = currentShow["name"]!.string
                        self.showDescriptionLabel.text = currentShow["description"]!.string
                        
                        if let starts = currentShow["starts"]!.string {
                            if let ends = currentShow["ends"]!.string {
                                
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:SS"
                                let startDate = dateFormatter.date(from: starts)
                                let endDate = dateFormatter.date(from: ends)
                                
                                dateFormatter.dateFormat = "h:mm a"
                                let startTime = dateFormatter.string(from: startDate!)
                                let endTime = dateFormatter.string(from: endDate!)
                                
                                self.showScheduleLabel.text = "from " + startTime + " to " + endTime
                            }
                        }
                    }
                    
                    if let currentTrackEnds = json["tracks"]["current"]["ends"].string {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:SS"
                        let endDate = dateFormatter.date(from: currentTrackEnds)
                        let elapsedTime = endDate!.timeIntervalSince(Date())
                        print(elapsedTime)
                        Timer.scheduledTimer(timeInterval: elapsedTime + 3, target: self, selector: #selector(RadioViewController.refreshInfo), userInfo: nil, repeats: false)
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
                            ] as [String : Any]
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = songInfo
                        }
                    }
                    
                    UIView.animate(withDuration: 0.5, animations: { () -> Void in
                        self.showView.alpha = 1
                    })
                    
                }
            }
            
        }) 
        
        task.resume()
    }
    
    // MARK: KVO
    
    override internal func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        //if let change = change as [NSKeyValueChangeKey :Any]
        //{
            //let status = change?[NSKeyValueChangeKey.newKey]!
        
        let status = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).intValue as AVPlayerStatus.RawValue
        
            switch (status) {
            case AVPlayerStatus.readyToPlay.rawValue:
                
                //toggleButton.setImage(UIImage(named: "pauseBtn")!, forState: UIControlState.Normal)
                //player.play()
                self.currentlyPlaying = true
                
            case AVPlayerStatus.failed.rawValue:
                print("Failed to stream audio")
                
            default: break
            }
            
        //}
        
    }

}

