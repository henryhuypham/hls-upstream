//
//  AVUtils.swift
//  SingSing
//
//  Created by Thuan Le Dinh on 9/13/17.
//  Copyright © 2017 Henry Pham. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation


@objc protocol AVUtilsDelegate: class {
    @objc optional func onNewDeviceAvailable(notification: Notification)
    @objc optional func onOldDeviceUnavailable(notification: Notification)
}

class AVUtils {
    
    private var delegate: AVUtilsDelegate?
  
    var isHeadphonesConnected: Bool {
        return AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            $0.portType == AVAudioSessionPortBluetoothHFP ||
            $0.portType == AVAudioSessionPortHeadphones ||
            $0.portType == AVAudioSessionPortBluetoothLE ||
            $0.portType == AVAudioSessionPortBluetoothA2DP
        }
    }
    
    init(delegate: AVUtilsDelegate?) {
        self.delegate = delegate
        NotificationCenter.default.addObserver(self, selector: #selector(self.audioRouteChangeListener(notification:)), name: .AVAudioSessionRouteChange, object: nil)
    }
    
    @objc func audioRouteChangeListener(notification: Notification) {
        guard let audioRouteChangeReason = notification.userInfo![AVAudioSessionRouteChangeReasonKey] as? UInt else {
            return
        }
        switch AVAudioSessionRouteChangeReason(rawValue: audioRouteChangeReason)! {
            
        case AVAudioSessionRouteChangeReason.oldDeviceUnavailable:
            delegate?.onOldDeviceUnavailable?(notification: notification)
        case AVAudioSessionRouteChangeReason.newDeviceAvailable:
            delegate?.onNewDeviceAvailable?(notification: notification)
        default:
            break
        }
    }
    
    func cleanUp() {
        delegate = nil
        NotificationCenter.default.removeObserver(self)
    }
}
