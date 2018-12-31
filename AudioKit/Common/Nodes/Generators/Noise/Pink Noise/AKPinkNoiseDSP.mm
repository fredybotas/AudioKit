//
//  AKPinkNoiseDSP.mm
//  AudioKit
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright © 2018 AudioKit. All rights reserved.
//

#include "AKPinkNoiseDSP.hpp"
#import "AKLinearParameterRamp.hpp"

extern "C" AKDSPRef createPinkNoiseDSP(int nChannels, double sampleRate) {
    AKPinkNoiseDSP *dsp = new AKPinkNoiseDSP();
    dsp->init(nChannels, sampleRate);
    return dsp;
}

struct AKPinkNoiseDSP::InternalData {
    sp_pinknoise *_pinknoise;
    AKLinearParameterRamp amplitudeRamp;
};

AKPinkNoiseDSP::AKPinkNoiseDSP() : data(new InternalData) {
    data->amplitudeRamp.setTarget(defaultAmplitude, true);
    data->amplitudeRamp.setDurationInSamples(defaultRampDurationSamples);
}

// Uses the ParameterAddress as a key
void AKPinkNoiseDSP::setParameter(AUParameterAddress address, AUValue value, bool immediate) {
    switch (address) {
        case AKPinkNoiseParameterAmplitude:
            data->amplitudeRamp.setTarget(clamp(value, amplitudeLowerBound, amplitudeUpperBound), immediate);
            break;
        case AKPinkNoiseParameterRampDuration:
            data->amplitudeRamp.setRampDuration(value, _sampleRate);
            break;
    }
}

// Uses the ParameterAddress as a key
float AKPinkNoiseDSP::getParameter(uint64_t address) {
    switch (address) {
        case AKPinkNoiseParameterAmplitude:
            return data->amplitudeRamp.getTarget();
        case AKPinkNoiseParameterRampDuration:
            return data->amplitudeRamp.getRampDuration(_sampleRate);
    }
    return 0;
}

void AKPinkNoiseDSP::init(int _channels, double _sampleRate) {
    AKSoundpipeDSPBase::init(_channels, _sampleRate);
    sp_pinknoise_create(&data->_pinknoise);
    sp_pinknoise_init(_sp, data->_pinknoise);
    data->_pinknoise->amp = defaultAmplitude;
}

void AKPinkNoiseDSP::deinit() {
    sp_pinknoise_destroy(&data->_pinknoise);
}

void AKPinkNoiseDSP::process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) {

    for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
        int frameOffset = int(frameIndex + bufferOffset);

        // do ramping every 8 samples
        if ((frameOffset & 0x7) == 0) {
            data->amplitudeRamp.advanceTo(_now + frameOffset);
        }

        data->_pinknoise->amp = data->amplitudeRamp.getValue();

        float temp = 0;
        for (int channel = 0; channel < _nChannels; ++channel) {
            float *out = (float *)_outBufferListPtr->mBuffers[channel].mData + frameOffset;

            if (_playing) {
                if (channel == 0) {
                    sp_pinknoise_compute(_sp, data->_pinknoise, nil, &temp);
                }
                *out = temp;
            } else {
                *out = 0.0;
            }
        }
    }
}
