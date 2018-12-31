//
//  AKCostelloReverbDSP.mm
//  AudioKit
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright © 2018 AudioKit. All rights reserved.
//

#include "AKCostelloReverbDSP.hpp"
#import "AKLinearParameterRamp.hpp"

extern "C" AKDSPRef createCostelloReverbDSP(int nChannels, double sampleRate) {
    AKCostelloReverbDSP *dsp = new AKCostelloReverbDSP();
    dsp->init(nChannels, sampleRate);
    return dsp;
}

struct AKCostelloReverbDSP::InternalData {
    sp_revsc *_revsc;
    AKLinearParameterRamp feedbackRamp;
    AKLinearParameterRamp cutoffFrequencyRamp;
};

AKCostelloReverbDSP::AKCostelloReverbDSP() : data(new InternalData) {
    data->feedbackRamp.setTarget(defaultFeedback, true);
    data->feedbackRamp.setDurationInSamples(defaultRampDurationSamples);
    data->cutoffFrequencyRamp.setTarget(defaultCutoffFrequency, true);
    data->cutoffFrequencyRamp.setDurationInSamples(defaultRampDurationSamples);
}

// Uses the ParameterAddress as a key
void AKCostelloReverbDSP::setParameter(AUParameterAddress address, AUValue value, bool immediate) {
    switch (address) {
        case AKCostelloReverbParameterFeedback:
            data->feedbackRamp.setTarget(clamp(value, feedbackLowerBound, feedbackUpperBound), immediate);
            break;
        case AKCostelloReverbParameterCutoffFrequency:
            data->cutoffFrequencyRamp.setTarget(clamp(value, cutoffFrequencyLowerBound, cutoffFrequencyUpperBound), immediate);
            break;
        case AKCostelloReverbParameterRampDuration:
            data->feedbackRamp.setRampDuration(value, _sampleRate);
            data->cutoffFrequencyRamp.setRampDuration(value, _sampleRate);
            break;
    }
}

// Uses the ParameterAddress as a key
float AKCostelloReverbDSP::getParameter(uint64_t address) {
    switch (address) {
        case AKCostelloReverbParameterFeedback:
            return data->feedbackRamp.getTarget();
        case AKCostelloReverbParameterCutoffFrequency:
            return data->cutoffFrequencyRamp.getTarget();
        case AKCostelloReverbParameterRampDuration:
            return data->feedbackRamp.getRampDuration(_sampleRate);
    }
    return 0;
}

void AKCostelloReverbDSP::init(int _channels, double _sampleRate) {
    AKSoundpipeDSPBase::init(_channels, _sampleRate);
    sp_revsc_create(&data->_revsc);
    sp_revsc_init(_sp, data->_revsc);
    data->_revsc->feedback = defaultFeedback;
    data->_revsc->lpfreq = defaultCutoffFrequency;
}

void AKCostelloReverbDSP::deinit() {
    sp_revsc_destroy(&data->_revsc);
}

void AKCostelloReverbDSP::process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) {

    for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
        int frameOffset = int(frameIndex + bufferOffset);

        // do ramping every 8 samples
        if ((frameOffset & 0x7) == 0) {
            data->feedbackRamp.advanceTo(_now + frameOffset);
            data->cutoffFrequencyRamp.advanceTo(_now + frameOffset);
        }

        data->_revsc->feedback = data->feedbackRamp.getValue();
        data->_revsc->lpfreq = data->cutoffFrequencyRamp.getValue();

        float *tmpin[2];
        float *tmpout[2];
        for (int channel = 0; channel < _nChannels; ++channel) {
            float *in  = (float *)_inBufferListPtr->mBuffers[channel].mData  + frameOffset;
            float *out = (float *)_outBufferListPtr->mBuffers[channel].mData + frameOffset;
            
            if (channel < 2) {
                tmpin[channel] = in;
                tmpout[channel] = out;
            }
            if (!_playing) {
                *out = *in;
            }
        }
        if (_playing) {
            sp_revsc_compute(_sp, data->_revsc, tmpin[0], tmpin[1], tmpout[0], tmpout[1]);
        }
    }
}
