//
//  AudioSuperpowered.swift
//  SingSing
//
//  Created by JBach on 10/3/17.
//  Copyright © 2017 Henry Pham. All rights reserved.
//

import Foundation

class AudioSuperpower: AVUtilsDelegate {
    
    var superpowered: Superpowered!
    var avUtils: AVUtils!
    var pluginHeadphoneInOutBlock: (()->Void)?
    var blockWriteToFileSuccess: ((String)->Void)?
    init() {
        superpowered = Superpowered()
        avUtils = AVUtils(delegate: self)
        superpowered.writeToFileSuccess = { urlString in
            self.blockWriteToFileSuccess?(urlString!)
        }
        
        detectHeadphone()
    }
//
//    func setupEffect(_ effect: SuperpoweredEffect) {
//        superpowered.setBandEQWithLow(effect.bandEQ.low,
//                                      mid: effect.bandEQ.mid,
//                                      high: effect.bandEQ.high,
//                                      enable: effect.bandEQ.enable)
//
//        superpowered.setupGate(effect.gateEnable)
//        superpowered.setupRoll(effect.rollEnable)
//
//        superpowered.setupEchos(effect.echo.mix,
//                                enable: effect.echo.enable)
//
//        superpowered.setupFilters(effect.filter.type,
//                                  withFrequency: effect.filter.frequency,
//                                  octave: effect.filter.octave,
//                                  decibel: effect.filter.decibel,
//                                  resonance: effect.filter.resonace,
//                                  slope: effect.filter.resonace,
//                                  dbGain: effect.filter.dbGain,
//                                  enable: effect.filter.enable)
//
//        superpowered.setupReverbs(effect.reverb.mix,
//                                  effect.reverb.damp,
//                                  effect.reverb.roomSize,
//                                  enable: effect.reverb.enable)
//
//        superpowered.setupFlanger(effect.flanger.wet,
//                                  lfoBeats: effect.flanger.LFOBeats,
//                                  depth: effect.flanger.depth,
//                                  enable: effect.flanger.enable)
//    }
    
    func setupRecordAudio() {
        superpowered.setupRecord()
    }
    
    func start() {
        superpowered.start()
    }
    
    func stop() {
        superpowered.stop()
    }
    
    func startRecord() {
        superpowered.startRecordAudio()
    }
    
    func pauseRecord() {
        superpowered.pauseRecordAudio()
    }
    
    func resumeRecord() {
        superpowered.resumeRecordAudio()
    }
    
    func stopRecord() {
        superpowered.stopRecordAudio()
    }

    func cleanUp() {
        superpowered.stop()
        superpowered.resetEffect()
        superpowered = nil
        
        avUtils.cleanUp()
        avUtils = nil
    }
    
    // MARK: AVUtilDelegate
    
    private func detectHeadphone() {
        if let headphoneConnected = avUtils?.isHeadphonesConnected , headphoneConnected == true {
            start()
        }
    }
    
    func onNewDeviceAvailable(notification: Notification) {
        if let headphoneConnected = avUtils?.isHeadphonesConnected, headphoneConnected == true {
            start()
            pluginHeadphoneInOutBlock?()
        }
    }
    
    func onOldDeviceUnavailable(notification: Notification) {
        if let headphoneConnected = avUtils?.isHeadphonesConnected, headphoneConnected == false {
            stop()
            pluginHeadphoneInOutBlock?()
        }
    }
    
    // MARK: Helpers
    
    func getAudioFilePath() -> String {
        return superpowered.audioFilePath + ".wav"
    }
}
