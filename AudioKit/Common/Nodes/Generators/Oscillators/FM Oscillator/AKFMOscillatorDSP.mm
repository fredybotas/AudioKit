//
//  AKFMOscillatorDSP.mm
//  AudioKit
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright © 2018 AudioKit. All rights reserved.
//

#include "AKFMOscillatorDSP.hpp"
#import "AKLinearParameterRamp.hpp"

extern "C" AKDSPRef createFMOscillatorDSP(int nChannels, double sampleRate) {
    AKFMOscillatorDSP *dsp = new AKFMOscillatorDSP();
    dsp->init(nChannels, sampleRate);
    return dsp;
}

struct AKFMOscillatorDSP::InternalData {
    sp_fosc *_fosc;
    sp_ftbl *_ftbl;
    UInt32 _ftbl_size = 4096;
    AKLinearParameterRamp baseFrequencyRamp;
    AKLinearParameterRamp carrierMultiplierRamp;
    AKLinearParameterRamp modulatingMultiplierRamp;
    AKLinearParameterRamp modulationIndexRamp;
    AKLinearParameterRamp amplitudeRamp;
};

AKFMOscillatorDSP::AKFMOscillatorDSP() : data(new InternalData) {
    data->baseFrequencyRamp.setTarget(defaultBaseFrequency, true);
    data->baseFrequencyRamp.setDurationInSamples(defaultRampDurationSamples);
    data->carrierMultiplierRamp.setTarget(defaultCarrierMultiplier, true);
    data->carrierMultiplierRamp.setDurationInSamples(defaultRampDurationSamples);
    data->modulatingMultiplierRamp.setTarget(defaultModulatingMultiplier, true);
    data->modulatingMultiplierRamp.setDurationInSamples(defaultRampDurationSamples);
    data->modulationIndexRamp.setTarget(defaultModulationIndex, true);
    data->modulationIndexRamp.setDurationInSamples(defaultRampDurationSamples);
    data->amplitudeRamp.setTarget(defaultAmplitude, true);
    data->amplitudeRamp.setDurationInSamples(defaultRampDurationSamples);
}

// Uses the ParameterAddress as a key
void AKFMOscillatorDSP::setParameter(AUParameterAddress address, AUValue value, bool immediate) {
    switch (address) {
        case AKFMOscillatorParameterBaseFrequency:
            data->baseFrequencyRamp.setTarget(clamp(value, baseFrequencyLowerBound, baseFrequencyUpperBound), immediate);
            break;
        case AKFMOscillatorParameterCarrierMultiplier:
            data->carrierMultiplierRamp.setTarget(clamp(value, carrierMultiplierLowerBound, carrierMultiplierUpperBound), immediate);
            break;
        case AKFMOscillatorParameterModulatingMultiplier:
            data->modulatingMultiplierRamp.setTarget(clamp(value, modulatingMultiplierLowerBound, modulatingMultiplierUpperBound), immediate);
            break;
        case AKFMOscillatorParameterModulationIndex:
            data->modulationIndexRamp.setTarget(clamp(value, modulationIndexLowerBound, modulationIndexUpperBound), immediate);
            break;
        case AKFMOscillatorParameterAmplitude:
            data->amplitudeRamp.setTarget(clamp(value, amplitudeLowerBound, amplitudeUpperBound), immediate);
            break;
        case AKFMOscillatorParameterRampDuration:
            data->baseFrequencyRamp.setRampDuration(value, _sampleRate);
            data->carrierMultiplierRamp.setRampDuration(value, _sampleRate);
            data->modulatingMultiplierRamp.setRampDuration(value, _sampleRate);
            data->modulationIndexRamp.setRampDuration(value, _sampleRate);
            data->amplitudeRamp.setRampDuration(value, _sampleRate);
            break;
    }
}

// Uses the ParameterAddress as a key
float AKFMOscillatorDSP::getParameter(uint64_t address) {
    switch (address) {
        case AKFMOscillatorParameterBaseFrequency:
            return data->baseFrequencyRamp.getTarget();
        case AKFMOscillatorParameterCarrierMultiplier:
            return data->carrierMultiplierRamp.getTarget();
        case AKFMOscillatorParameterModulatingMultiplier:
            return data->modulatingMultiplierRamp.getTarget();
        case AKFMOscillatorParameterModulationIndex:
            return data->modulationIndexRamp.getTarget();
        case AKFMOscillatorParameterAmplitude:
            return data->amplitudeRamp.getTarget();
        case AKFMOscillatorParameterRampDuration:
            return data->baseFrequencyRamp.getRampDuration(_sampleRate);
    }
    return 0;
}

void AKFMOscillatorDSP::init(int _channels, double _sampleRate) {
    AKSoundpipeDSPBase::init(_channels, _sampleRate);
    _playing = false;
    sp_fosc_create(&data->_fosc);
    sp_fosc_init(_sp, data->_fosc, data->_ftbl);
    data->_fosc->freq = defaultBaseFrequency;
    data->_fosc->car = defaultCarrierMultiplier;
    data->_fosc->mod = defaultModulatingMultiplier;
    data->_fosc->indx = defaultModulationIndex;
    data->_fosc->amp = defaultAmplitude;
}

void AKFMOscillatorDSP::deinit() {
    sp_fosc_destroy(&data->_fosc);
}

void AKFMOscillatorDSP::setupWaveform(uint32_t size) {
    data->_ftbl_size = size;
    sp_ftbl_create(_sp, &data->_ftbl, data->_ftbl_size);
}

void AKFMOscillatorDSP::setWaveformValue(uint32_t index, float value) {
    data->_ftbl->tbl[index] = value;
}
void AKFMOscillatorDSP::process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) {

    for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
        int frameOffset = int(frameIndex + bufferOffset);

        // do ramping every 8 samples
        if ((frameOffset & 0x7) == 0) {
            data->baseFrequencyRamp.advanceTo(_now + frameOffset);
            data->carrierMultiplierRamp.advanceTo(_now + frameOffset);
            data->modulatingMultiplierRamp.advanceTo(_now + frameOffset);
            data->modulationIndexRamp.advanceTo(_now + frameOffset);
            data->amplitudeRamp.advanceTo(_now + frameOffset);
        }

        data->_fosc->freq = data->baseFrequencyRamp.getValue();
        data->_fosc->car = data->carrierMultiplierRamp.getValue();
        data->_fosc->mod = data->modulatingMultiplierRamp.getValue();
        data->_fosc->indx = data->modulationIndexRamp.getValue();
        data->_fosc->amp = data->amplitudeRamp.getValue();

        float temp = 0;
        for (int channel = 0; channel < _nChannels; ++channel) {
            float *out = (float *)_outBufferListPtr->mBuffers[channel].mData + frameOffset;

            if (_playing) {
                if (channel == 0) {
                    sp_fosc_compute(_sp, data->_fosc, nil, &temp);
                }
                *out = temp;
            } else {
                *out = 0.0;
            }
        }
    }
}
