//
//  VideoProcessManager.swift
//  SingSing
//
//  Created by JBach.iOS on 8/9/17.
//  Copyright © 2017 Henry Pham. All rights reserved.
//

import Foundation
import AVFoundation
import Photos


struct AudioTrack {
    let asset: AVAsset
    let audioTrack: AVAssetTrack
}

struct VideoTrack {
    let asset: AVAsset
    let videoTrack: AVAssetTrack
}

class VideoProcessManager: NSObject {

    static let DEFAULT_RENDER_OUTPUT = CGSize(width: 640, height: 640)
    static let DEFAULT_FPS: Int32 = 30
    static let DEFAULT_FILE_TYPE = AVFileType.mp3

    private var renderSize = DEFAULT_RENDER_OUTPUT
    private var frameDuration = CMTimeMake(1, DEFAULT_FPS)
    private var outputFileType = DEFAULT_FILE_TYPE

    private let mixComposition = AVMutableComposition()
    private var audioTracks = [AudioTrack]()
    private static var startTime: Double = 0

    func add(audioURL: URL) -> VideoProcessManager {
        let audioAsset = AVAsset(url: audioURL)
        let audioTrackAsset = audioAsset.tracks(withMediaType: .audio)[0]

        audioTracks.append(AudioTrack(asset: audioAsset,
                audioTrack: audioTrackAsset))

        return self
    }

    func renderSize(width: Int, height: Int) -> VideoProcessManager {
        renderSize = CGSize(width: width, height: height)
        return self
    }

    func framePerSec(fps: Int32) -> VideoProcessManager {
        frameDuration = CMTimeMake(1, fps)
        return self
    }


    func output(fileType: AVFileType) -> VideoProcessManager {
        outputFileType = fileType
        return self
    }

    func merge(onSuccess: @escaping (URL) -> Void, onError: @escaping (Error) -> Void) {
        let audioTrack1 = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack2 = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        do {
            try audioTrack1?.insertTimeRange(CMTimeRangeMake(kCMTimeZero, audioTracks[0].asset.duration),
                                             of: audioTracks[0].audioTrack,
                                             at: kCMTimeZero)
            try audioTrack2?.insertTimeRange(CMTimeRangeMake(CMTime(seconds: VideoProcessManager.startTime, preferredTimescale: 1000), audioTracks[0].asset.duration),
                                             of: audioTracks[1].audioTrack,
                                             at: kCMTimeZero)
            print("\(VideoProcessManager.startTime),")
            VideoProcessManager.startTime += audioTracks[0].asset.duration.seconds
        } catch {
            onError(error)
        }

        //export result
        exportVideo(
                asset: mixComposition,
                onSuccess: { url in
                    onSuccess(url)
                },
                onError: { error in
                    onError(error)
                }
        )
    }

    private func exportVideo(asset: AVAsset, onSuccess: @escaping (URL) -> Void, onError: @escaping (Error) -> Void) {
        let savePathUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "Audio-\(VideoProcessManager.getTimeNow()).mp4")
        let assetExport: AVAssetExportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetLowQuality)!
        assetExport.outputFileType = AVFileType.mp4
        assetExport.outputURL = savePathUrl
        assetExport.shouldOptimizeForNetworkUse = true

        assetExport.exportAsynchronously { () -> Void in
            switch assetExport.status {
            case AVAssetExportSessionStatus.completed:
                onSuccess(savePathUrl)
            case AVAssetExportSessionStatus.failed:
                onError(assetExport.error!)
            case AVAssetExportSessionStatus.cancelled:
                onError(assetExport.error!)
            default:
                return
            }
        }
    }
    
    class func getThumbnailVideo(videoUrl: URL, second: Int32) -> UIImage {
        let video = AVAsset(url: videoUrl)
        let imgGenerator = AVAssetImageGenerator(asset: video)
        let cgImage = try! imgGenerator.copyCGImage(at: CMTimeMake(0, second), actualTime: nil)
        return UIImage(cgImage: cgImage)
    }
    
    class func getTimeNow() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYMMdd-HHmmss"
        return dateFormatter.string(from: Date())
    }
    
    class func removeFile(fileUrl: URL) {
        let fileManager = FileManager.default
        let filePath = fileUrl.path
        if fileManager.fileExists(atPath: filePath) {
            do {
                try fileManager.removeItem(atPath: filePath)
            } catch {
                //todo show error
            }
        }
    }
}

