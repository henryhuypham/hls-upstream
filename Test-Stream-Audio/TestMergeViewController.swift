//
//  TestMergeViewController.swift
//  Test-Stream-Audio
//
//  Created by Henry Pham on 12/6/17.
//  Copyright © 2017 JBach. All rights reserved.
//

import UIKit
import AVFoundation

class TestMergeViewController: UIViewController {
    
    let data1 = [
        0.0,
        1.99691609977324,
        3.99383219954649,
        6.00235827664399,
        7.99927437641723,
        9.99619047619048,
        11.9931065759637,
        14.0016326530612,
        15.9985487528345,
        17.9954648526077,
        19.992380952381,
        21.9892970521542,
        23.9862131519274,
        25.9831292517007,
        27.9916553287982,
        29.9885714285714,
        31.9854875283447,
        33.9824036281179,
        35.9909297052154,
        37.9878458049887,
        39.9847619047619,
        41.9816780045352,
        43.9902040816327,
        45.9871201814059,
        47.9840362811792,
        49.9809523809524,
        51.9894784580499,
        53.9863945578232,
        55.9833106575964,
        57.9918367346939,
        59.9887528344672,
        61.9856689342404,
        63.9825850340136,
        65.9911111111112,
        67.9880272108844,
        69.9849433106576,
        71.9818594104309,
        73.9903854875284,
        75.9873015873016,
        77.9842176870749,
        79.9811337868481,
        81.9896598639456,
        83.9865759637189,
        85.9834920634921,
        87.9920181405896,
        89.9889342403629,
        91.9858503401361,
        93.9827664399093,
        95.9912925170068,
        97.9882086167801,
        99.9851247165533,
        101.982040816327
    ]
    let data2: [Double] = [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
        17,
        18,
        19,
        20,
        21,
        22,
        23,
        24,
        25,
        26,
        27,
        28,
        29,
        30,
        31,
        32,
        33,
        34,
        35,
        36,
        37,
        38,
        39,
        40,
        41,
        42,
        43,
        44,
        45,
        46,
        47,
        48,
        49,
        50,
        51,
        52,
        53,
        54,
        55,
        56,
        57,
        58,
        59,
        60,
        61,
        62,
        63,
        64,
        65,
        66,
        67,
        68,
        69,
        70,
        71,
        72,
        73,
        74,
        75,
        76,
        77,
        78,
        79,
        80,
        81,
        82,
        83,
        84,
        85,
        86,
        87,
        88,
        89,
        90,
        91,
        92,
        93,
        94,
        95,
        96,
        97,
        98,
        99,
        100,
        101
    ]
    let beatURL = Bundle.main.url(forResource: "beat", withExtension: "mp3")

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func merge(_ sender: Any) {
        mergeAudio()
    }
    
    private func mergeAudio() {
        do {
            let mixComposition = AVMutableComposition()
            let data = data1
            
            for i in 0..<data.count-1 {
                let audioAsset = AVAsset(url: beatURL!)
                let audioTrackAsset = audioAsset.tracks(withMediaType: AVMediaTypeAudio)[0]
                let trackResource = AudioTrack(asset: audioAsset, audioTrack: audioTrackAsset)
                
                let audioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
                try audioTrack.insertTimeRange(CMTimeRangeMake(CMTime(seconds: data[i], preferredTimescale: 10000), CMTime(seconds: data[i + 1] - data[i], preferredTimescale: 10000)),
                                                of: trackResource.audioTrack,
                                                at: CMTime(seconds: data[i], preferredTimescale: 10000))
            }
            
            let savePathUrl = URL(fileURLWithPath: NSTemporaryDirectory() + "Merged.mp4")
            let assetExport: AVAssetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetMediumQuality)!
            assetExport.outputFileType = AVFileTypeMPEG4
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
}
