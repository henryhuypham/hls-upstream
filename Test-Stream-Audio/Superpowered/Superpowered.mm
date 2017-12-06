#import "Superpowered.h"
#import "SuperpoweredIOSAudioIO.h"
#include "SuperpoweredFrequencyDomain.h"
#include "SuperpoweredSimple.h"
#import "SuperpoweredEcho.h"
#import "SuperpoweredReverb.h"
#import "SuperpoweredFlanger.h"
#import "Superpowered3BandEQ.h"
#import "SuperpoweredWhoosh.h"
#import "SuperpoweredFilter.h"
#import "SuperpoweredGate.h"
#import "SuperpoweredRoll.h"
#import "SuperpoweredRecorder.h"

#define FFT_LOG_SIZE 11 // 2^11 = 2048

@implementation Superpowered {
    SuperpoweredIOSAudioIO *audioIO;
    SuperpoweredFrequencyDomain *frequencyDomain;
    float *magnitudeLeft, *magnitudeRight, *phaseLeft, *phaseRight, *fifoOutput;
    int fifoOutputFirstSample, fifoOutputLastSample, stepSize, fifoCapacity;
    
    SuperpoweredRecorder *recorder;
    bool isPauseRecord, headphoneConnected;
    FILE *fd;
    
    SuperpoweredFilter *filters;
    SuperpoweredReverb *reverbs;
    Superpowered3BandEQ *bandEQ;
    SuperpoweredEcho *echos;
    SuperpoweredFlanger *flanger;
    SuperpoweredGate *gate;
    SuperpoweredRoll *roll;
}

- (void)dealloc {
    [audioIO stop];
    audioIO = nil;
    
    delete recorder;
    delete frequencyDomain;
    delete filters;
    delete reverbs;
    delete bandEQ;
    delete echos;
    delete gate;
    delete roll;
    delete flanger;
    
    free(magnitudeLeft);
    free(magnitudeRight);
    free(phaseLeft);
    free(phaseRight);
    free(fifoOutput);
}

// This callback is called periodically by the audio system.
static bool audioProcessing(void *clientdata,
                            float **buffers,
                            unsigned int inputChannels,
                            unsigned int outputChannels,
                            unsigned int numberOfSamples,
                            unsigned int samplerate,
                            uint64_t hostTime) {
    __unsafe_unretained Superpowered *self = (__bridge Superpowered *)clientdata;
    // Input goes to the frequency domain.
    float interleaved[numberOfSamples * 2 + 16];
    SuperpoweredInterleave(buffers[0], buffers[1], interleaved, numberOfSamples);
    //process audioFX
    if (self->filters)  self->filters->process(interleaved, interleaved, numberOfSamples);
    if (self->bandEQ)   self->bandEQ->process(interleaved, interleaved, numberOfSamples);
    if (self->flanger)  self->flanger->process(interleaved, interleaved, numberOfSamples);
    if (self->echos)    self->echos->process(interleaved, interleaved, numberOfSamples);
    if (self->reverbs)  self->reverbs->process(interleaved, interleaved, numberOfSamples);

    //addinput
    if (!self->isPauseRecord) {
        self->recorder->process(interleaved, numberOfSamples);
    }
    
    if (self->headphoneConnected == true) {
        self->frequencyDomain->addInput(interleaved, numberOfSamples);
    }
    
    // In the frequency domain we are working with 1024 magnitudes and phases for every channel (left, right), if the fft size is 2048.
    while (self->frequencyDomain->timeDomainToFrequencyDomain(self->magnitudeLeft, self->magnitudeRight, self->phaseLeft, self->phaseRight)) {
        // You can work with frequency domain data from this point.
        
        // This is just a quick example: we remove the magnitude of the first 20 bins, meaning total bass cut between 0-430 Hz.
        memset(self->magnitudeLeft, 0, 0);
        memset(self->magnitudeRight, 0, 0);
        
        // We are done working with frequency domain data. Let's go back to the time domain.
        
        // Check if we have enough room in the fifo buffer for the output. If not, move the existing audio data back to the buffer's beginning.
        if (self->fifoOutputLastSample + self->stepSize >= self->fifoCapacity) { // This will be true for every 100th iteration only, so we save precious memory bandwidth.
            int samplesInFifo = self->fifoOutputLastSample - self->fifoOutputFirstSample;
            if (samplesInFifo > 0)
                memmove(self->fifoOutput, self->fifoOutput + self->fifoOutputFirstSample * 2, samplesInFifo * sizeof(float) * 2);
            self->fifoOutputFirstSample = 0;
            self->fifoOutputLastSample = samplesInFifo;
        };
        
        // Transforming back to the time domain.
        self->frequencyDomain->frequencyDomainToTimeDomain(self->magnitudeLeft, self->magnitudeRight, self->phaseLeft, self->phaseRight, self->fifoOutput + self->fifoOutputLastSample * 2);
        self->frequencyDomain->advance();
        self->fifoOutputLastSample += self->stepSize;
    };
    
    // If we have enough samples in the fifo output buffer, pass them to the audio output.
    if (self->fifoOutputLastSample - self->fifoOutputFirstSample >= numberOfSamples) {
        SuperpoweredDeInterleave(self->fifoOutput + self->fifoOutputFirstSample * 2, buffers[0], buffers[1], numberOfSamples);
        // buffers[0] and buffer[1] now have time domain audio output (left and right channels)
        self->fifoOutputFirstSample += numberOfSamples;
        return true;
    } else {
        return false;
    }
}

static void recordProcessing(void *clientData)
{
    __unsafe_unretained Superpowered *gro = (__bridge Superpowered *)clientData;
    return gro->_writeToFileSuccess([gro->_audioFilePath stringByAppendingString:@".txt"]);
}

- (id)init {
    self = [super init];
    if (!self) return nil;
    [self setupAudioIO];
    return self;
}

-(void) setupAudioIO {
    [self setupRecord];
    frequencyDomain = new SuperpoweredFrequencyDomain(FFT_LOG_SIZE); // This will do the main "magic".
    stepSize = frequencyDomain->fftSize / 4; // The default overlap ratio is 4:1, so we will receive this amount of samples from the frequency domain in one step.
    
    // Frequency domain data goes into these buffers:
    magnitudeLeft = (float *)malloc(frequencyDomain->fftSize * sizeof(float));
    magnitudeRight = (float *)malloc(frequencyDomain->fftSize * sizeof(float));
    phaseLeft = (float *)malloc(frequencyDomain->fftSize * sizeof(float));
    phaseRight = (float *)malloc(frequencyDomain->fftSize * sizeof(float));
    
    // Time domain result goes into a FIFO (first-in, first-out) buffer
    fifoOutputFirstSample = fifoOutputLastSample = 0;
    fifoCapacity = stepSize * 100; // Let's make the fifo's size 100 times more than the step size, so we save memory bandwidth.
    fifoOutput = (float *)malloc(fifoCapacity * sizeof(float) * 2 + 128);
    
    audioIO = [[SuperpoweredIOSAudioIO alloc] initWithDelegate: (id<SuperpoweredIOSAudioIODelegate>)self
                                           preferredBufferSize: 12
                                    preferredMinimumSamplerate: 44100
                                          audioSessionCategory: AVAudioSessionCategoryPlayAndRecord
                                                      channels: 2
                                       audioProcessingCallback: audioProcessing
                                                    clientdata: (__bridge void *)self];
    [audioIO start];
}

-(void) start {
    headphoneConnected = true;
}

-(void) stop {
    headphoneConnected = false;
}

// Superpowered Record

-(void) setupRecord {
    NSDate *date = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYMMDD-hhmmss"];
    NSString *timeString = [formatter stringFromDate:date];
    
    _audioFilePath = [[NSTemporaryDirectory() stringByAppendingString:@"audio"] stringByAppendingString:timeString];
    recorder = new SuperpoweredRecorder([_audioFilePath fileSystemRepresentation], 44100, 1, 2, false, recordProcessing, (__bridge void *)self);
    isPauseRecord = true;
}

-(void) startRecordAudio {
    isPauseRecord = false;
    recorder->start([_audioFilePath fileSystemRepresentation]);
//    NSLog(@"Start record");
}
-(void) pauseRecordAudio {
    NSLog(@"pause");
    isPauseRecord = true;
}

-(void) resumeRecordAudio {
    NSLog(@"resume");
    isPauseRecord = false;
}

-(void) stopRecordAudio {
//    NSLog(@"stop");
    isPauseRecord = true;
    recorder->stop();
}

//Superpowered AudioEffect

-(void)setupFilters: (FilterType)type
      withFrequency: (float)frequency
             Octave: (float)octave
            Decibel: (float)decibel
          Resonance: (float)resonace
              Slope: (float)slope
             dbGain: (float)dbGain
             enable: (bool)flag {
    
    SuperpoweredFilterType filterType;
    
    switch (type) {
        case LowShelf:
            filterType = SuperpoweredFilter_LowShelf;
            break;
        case HighShelf:
            filterType = SuperpoweredFilter_HighShelf;
            break;
        case Resonant_Lowpass:
            filterType = SuperpoweredFilter_Resonant_Lowpass;
            break;
        case Resonant_Highpass:
            filterType = SuperpoweredFilter_Resonant_Highpass;
            break;
        case Parametric:
            filterType = SuperpoweredFilter_Parametric;
            break;
        case Bandlimited_Notch:
            filterType = SuperpoweredFilter_Bandlimited_Notch;
            break;
        case Bandlimited_Bandpass:
            filterType = SuperpoweredFilter_Bandlimited_Bandpass;
            break;
        default:
            filterType = SuperpoweredFilter_Parametric;
            break;
    }
    
    if (!filters) filters = new SuperpoweredFilter(filterType, 44100);
    filters->reset();
    switch (type) {
        case SuperpoweredFilter_Resonant_Lowpass:
            filters->setResonantParameters(frequency, resonace);
            break;
        case SuperpoweredFilter_Resonant_Highpass:
            filters->setResonantParameters(frequency, resonace);
            break;
        case SuperpoweredFilter_Parametric:
            filters->setParametricParameters(frequency, octave, dbGain);
            break;
        case SuperpoweredFilter_LowShelf:
            filters->setShelfParameters(frequency, slope, dbGain);
            break;
        case SuperpoweredFilter_HighShelf:
            filters->setShelfParameters(frequency, slope, dbGain);
            break;
        case SuperpoweredFilter_Bandlimited_Notch:
            filters->setBandlimitedParameters(frequency, octave);
            break;
        case SuperpoweredFilter_Bandlimited_Bandpass:
            filters->setBandlimitedParameters(frequency, octave);
            break;
        default:
            filters->setResonantParameters(frequency, resonace);
            break;
    }
    filters->enable(flag);
}

-(void) setupEchos: (float)mix
            enable: (bool)flag {
    if (!echos) echos = new SuperpoweredEcho(44100);
    echos->reset();
    echos->setMix(mix);
    echos->enable(flag);
}

-(void) setupReverbs: (float)mix
                    : (float)damp
                    : (float)roomSize
              enable: (bool)flag {
    if (!reverbs) reverbs = new SuperpoweredReverb(44100);
    reverbs->reset();
    reverbs->setMix(mix);
    if (damp) reverbs->setDamp(damp);
    reverbs->setRoomSize(roomSize);
    reverbs->enable(flag);
}

-(void) setBandEQWithLow: (float)low
                     mid: (float)mid
                    high: (float)high
                  enable: (bool)flag {
    if (!bandEQ) bandEQ = new Superpowered3BandEQ(44100);
    bandEQ->reset();
    bandEQ->bands[0] = low;
    bandEQ->bands[1] = mid;
    bandEQ->bands[2] = high;
    bandEQ->enable(flag);
}

-(void) setupFlanger: (float)wet
            lfoBeats: (float)lfo
               depth: (float)depth
              enable: (bool)flag {
    if (!flanger) flanger = new SuperpoweredFlanger(44100);
    flanger->reset();
    flanger->setWet(wet);
    flanger->setDepth(depth);
    flanger->setLFOBeats(lfo);
    flanger->enable(flag);
}

-(void) setupGate: (bool)flag {
    if (!gate) gate = new SuperpoweredGate(44100);
    gate->reset();
    gate->enable(flag);
}

-(void) setupRoll: (bool)flag {
    if (!roll) roll = new SuperpoweredRoll(44100);
    roll->reset();
    roll->enable(flag);
}

-(void) resetEffect {
    if (filters) filters->reset();
    if (reverbs) reverbs->reset();
    if (bandEQ) bandEQ->reset();
    if (echos) echos->reset();
    if (gate) gate->reset();
    if (roll) roll->reset();
}

- (void)interruptionStarted {}
- (void)interruptionEnded {}
- (void)recordPermissionRefused {}
- (void)    mapChannels: (multiOutputChannelMap *)outputMap
               inputMap: (multiInputChannelMap *)inputMap
externalAudioDeviceName: (NSString *)externalAudioDeviceName
       outputsAndInputs: (NSString *)outputsAndInputs {}

@end

