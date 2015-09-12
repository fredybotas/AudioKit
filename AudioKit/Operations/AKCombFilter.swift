//
//  AKCombFilter.swift
//  AudioKit
//
//  Autogenerated by scripts by Aurelius Prochazka on 9/11/15.
//  Copyright (c) 2015 Aurelius Prochazka. All rights reserved.
//

import Foundation

/** Reverberates an input signal with a “colored” frequency response

This filter reiterates input with an echo density determined by loopDuration. The attenuation rate is independent and is determined by reverbDuration, the reverberation duration (defined as the time in seconds for a signal to decay to 1/1000, or 60dB down from its original amplitude). Output from a comb filter will appear only after loopDuration seconds.
*/
@objc class AKCombFilter : AKParameter {

    // MARK: - Properties

    private var comb = UnsafeMutablePointer<sp_comb>.alloc(1)

    private var input = AKParameter()

    /** The loop time of the filter, in seconds. This can also be thought of as the delay time. Determines frequency response curve, loopDuration * sr/2 peaks spaced evenly between 0 and sr/2. [Default Value: 0.1] */
    private var loopDuration: Float = 0


    /** The time in seconds for a signal to decay to 1/1000, or 60dB from its original amplitude. (aka RT-60). [Default Value: 1] */
    var reverbDuration: AKParameter = akp(1) {
        didSet { reverbDuration.bind(&comb.memory.revtime) }
    }


    // MARK: - Initializers

    /** Instantiates the filter with default values */
    init(input sourceInput: AKParameter)
    {
        super.init()
        input = sourceInput
        setup()
        bindAll()
    }

    /**
    Instantiates filter with constants

    - parameter loopDuration: The loop time of the filter, in seconds. This can also be thought of as the delay time. Determines frequency response curve, loopDuration * sr/2 peaks spaced evenly between 0 and sr/2. [Default Value: 0.1]
 */
    init (input sourceInput: AKParameter, loopDuration looptimeInput: Float) {
        super.init()
        input = sourceInput
        setup(looptimeInput)
        bindAll()
    }

    /**
    Instantiates the filter with all values

    - parameter input: Input audio signal. 
    - parameter reverbDuration: The time in seconds for a signal to decay to 1/1000, or 60dB from its original amplitude. (aka RT-60). [Default Value: 1]
    - parameter loopDuration: The loop time of the filter, in seconds. This can also be thought of as the delay time. Determines frequency response curve, loopDuration * sr/2 peaks spaced evenly between 0 and sr/2. [Default Value: 0.1]
    */
    convenience init(
        input          sourceInput:   AKParameter,
        reverbDuration revtimeInput:  AKParameter,
        loopDuration   looptimeInput: Float)
    {
        self.init(input: sourceInput, loopDuration: looptimeInput)
        reverbDuration = revtimeInput

        bindAll()
    }

    // MARK: - Internals

    /** Bind every property to the internal filter */
    internal func bindAll() {
        reverbDuration.bind(&comb.memory.revtime)
    }

    /** Internal set up function */
    internal func setup(loopDuration: Float = 0.1)
 {
        sp_comb_create(&comb)
        sp_comb_init(AKManager.sharedManager.data, comb, loopDuration)
    }

    /** Computation of the next value */
    override func compute() {
        sp_comb_compute(AKManager.sharedManager.data, comb, &(input.leftOutput), &leftOutput);
        rightOutput = leftOutput
    }

    /** Release of memory */
    override func teardown() {
        sp_comb_destroy(&comb)
    }
}
