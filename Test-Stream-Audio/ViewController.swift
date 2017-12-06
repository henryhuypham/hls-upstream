//
//  ViewController.swift
//  Test-Stream-Audio
//
//  Created by JBach on 12/1/17.
//  Copyright © 2017 JBach. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    var superpowered: AudioSuperpower!
    var timer: Timer!
    var tmpDirpath: String = ""
    
    let videoProcessManager = VideoProcessManager()
    let segmentDuration: Double = 2
    let beatURL = Bundle.main.url(forResource: "beat", withExtension: "mp3")
    var audioPlayer: AVAudioPlayer!
    let queue = DispatchQueue(label: "Timer Mergefile Queue", qos: .background, attributes: .concurrent, autoreleaseFrequency: .workItem, target: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createSuperpowered()
        setupAudioPlayer()
    }
    
    @IBAction func startRecord() {
        audioPlayer.play()
        superpowered.setupRecordAudio()
        superpowered.startRecord()

        timer = Timer.scheduledTimer(withTimeInterval: segmentDuration, repeats: true, block: { (timer) in
            self.loopWriteToFile()
        })
    }
    
    @IBAction func stopRecord() {
        audioPlayer.stop()
        superpowered.stopRecord()
        timer.invalidate()
    }
    
    @IBAction func mergeRecord(_ sender: Any) {
        let lastSepMark = tmpDirpath.range(of: "/", options: .backwards, range: nil, locale: nil)
        let dirPath = tmpDirpath.substring(to: lastSepMark!.upperBound)
        var startTime: Double = 0
        
        do {
            let mixComposition = AVMutableComposition()
            
            let mp4Files = try FileManager.default.contentsOfDirectory(atPath: dirPath).filter {
                $0.hasSuffix("mp4")
            }.sorted()
            
            for file in mp4Files {
                let filePath = "\(dirPath)\(file)"  
                let audioAsset = AVAsset(url: URL(fileURLWithPath: filePath))
                let audioTrackAsset = audioAsset.tracks(withMediaType: .audio)[0]
                let trackResource = AudioTrack(asset: audioAsset, audioTrack: audioTrackAsset)
                
                let audioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                try audioTrack?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, trackResource.asset.duration),
                                                of: trackResource.audioTrack,
                                                at: CMTime(seconds: startTime, preferredTimescale: 1000))
                
                startTime += trackResource.asset.duration.seconds
            }
            
            let savePathUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "Merged.mp4")
            let assetExport: AVAssetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetLowQuality)!
            assetExport.outputFileType = AVFileType.mp4
            assetExport.outputURL = savePathUrl
            assetExport.shouldOptimizeForNetworkUse = true
            
            assetExport.exportAsynchronously { () -> Void in
                switch assetExport.status {
                case AVAssetExportSessionStatus.completed:
                    print("==== Success ====")
                    print(savePathUrl)
                case AVAssetExportSessionStatus.failed:
                    print("==== Failed ====")
                case AVAssetExportSessionStatus.cancelled:
                    print("==== Canceled ====")
                default:
                    return
                }
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    //Mark: - Helper
    
    func setupAudioPlayer() {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: beatURL!)
        } catch  {
            print(error.localizedDescription)
        }
    }
    
    func createSuperpowered() {
        superpowered = AudioSuperpower()
        superpowered.blockWriteToFileSuccess = { urlString in
            let filePath = self.superpowered.getAudioFilePath()
            self.tmpDirpath = filePath
            
            self.queue.async {
                let mergeTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { (timer) in
                    if FileManager.default.fileExists(atPath: filePath) {
                        VideoProcessManager()
                            .add(audioURL: URL(fileURLWithPath: filePath))
                            .add(audioURL: self.beatURL!)
                            .merge(
                                onSuccess: { (url) in
//                                    print("===== merged: \(url.absoluteString)")
//                                    print("time: ", VideoProcessManager.getTimeNow())
                                    timer.invalidate()
                                },
                                onError: { error in
                                    print(error.localizedDescription)
                                })
                    }
                })
                
                let runloop = RunLoop.current
                runloop.add(mergeTimer, forMode: .commonModes)
                runloop.run()
            }
        }
    }
    
    func loopWriteToFile() {
        superpowered.stopRecord()
        superpowered.setupRecordAudio()
        superpowered.startRecord()
    }
}
