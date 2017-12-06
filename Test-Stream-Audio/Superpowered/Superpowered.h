//
//  Superpowered.h
//  SuperPowered
//
//  Created by JBach on 9/25/17.
//  Copyright © 2017 JBach. All rights reserved.
//
#import <Foundation/Foundation.h>

typedef enum FilterType {
    Resonant_Lowpass,
    Resonant_Highpass,
    Bandlimited_Bandpass,
    Bandlimited_Notch,
    LowShelf,
    HighShelf,
    Parametric,
} FilterType;
     
@interface Superpowered : NSObject

@property (strong, nonatomic) NSString *audioFilePath;
@property (strong, nonatomic) void(^writeToFileSuccess)(NSString *);

-(void) start;
-(void) stop;

-(void) setupFlanger : (float)wet
             lfoBeats: (float)lfo
                depth: (float)depth
               enable: (bool)flag;

-(void) setupReverbs: (float)mix
                    : (float)damp
                    : (float)roomSize
              enable: (bool)flag;

-(void)setupFilters: (FilterType)type
      withFrequency: (float)frequency
             Octave: (float)octave
            Decibel: (float)decibel
          Resonance: (float)resonace
              Slope: (float)slope
             dbGain: (float)dbGain
             enable: (bool)flag;

-(void) setupEchos: (float)mix
            enable: (bool)flag;


-(void) setBandEQWithLow: (float)low
                     mid: (float)mid
                    high: (float)high
                  enable: (bool)flag;

-(void) setupRoll : (bool)flag;
-(void) setupGate : (bool)flag;

-(void) resetEffect;

-(void) setupRecord;
-(void) startRecordAudio;
-(void) pauseRecordAudio;
-(void) resumeRecordAudio;
-(void) stopRecordAudio;

@end
