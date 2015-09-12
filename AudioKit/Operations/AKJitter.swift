//
//  AKJitter.swift
//  AudioKit
//
//  Autogenerated by scripts by Aurelius Prochazka on 9/11/15.
//  Copyright (c) 2015 Aurelius Prochazka. All rights reserved.
//

import Foundation

/** Generates a segmented line whose segments are randomly generated.

Produce a signal with random fluctuations (aka... jitter). This is useful for emulating jitter found in analogue equipment.
This operation generates a segmented line whose segments are randomly generated inside the interval amplitude to -amplitude. Duration of each segment is a random value generated according to minimum and maximum frequency values.
This can be used to make more natural and “analog-sounding” some static, dull sound. For best results, it is suggested to keep its amplitude moderate.
*/
@objc class AKJitter : AKParameter {

    // MARK: - Properties

    private var jitter = UnsafeMutablePointer<sp_jitter>.alloc(1)


    /** The amplitude of the jitter deviation line. Will produce values in the range of (+/-)amp. [Default Value: 1] */
    var amplitude: AKParameter = akp(1) {
        didSet { amplitude.bind(&jitter.memory.amp) }
    }

    /** Minimum speed of random frequency variations (expressed in Hz). [Default Value: 0.5] */
    var minimumFrequency: AKParameter = akp(0.5) {
        didSet { minimumFrequency.bind(&jitter.memory.cpsMin) }
    }

    /** Maximum speed of random frequency variations (expressed in Hz). [Default Value: 60] */
    var maximumFrequency: AKParameter = akp(60) {
        didSet { maximumFrequency.bind(&jitter.memory.cpsMax) }
    }


    // MARK: - Initializers

    /** Instantiates the jitter with default values */
    override init()
    {
        super.init()
        setup()
        bindAll()
    }

    /**
    Instantiates the jitter with all values

    - parameter amplitude: The amplitude of the jitter deviation line. Will produce values in the range of (+/-)amp. [Default Value: 1]
    - parameter minimumFrequency: Minimum speed of random frequency variations (expressed in Hz). [Default Value: 0.5]
    - parameter maximumFrequency: Maximum speed of random frequency variations (expressed in Hz). [Default Value: 60]
    */
    convenience init(
        amplitude        ampInput:    AKParameter,
        minimumFrequency cpsMinInput: AKParameter,
        maximumFrequency cpsMaxInput: AKParameter)
    {
        self.init()

        amplitude        = ampInput
        minimumFrequency = cpsMinInput
        maximumFrequency = cpsMaxInput

        bindAll()
    }

    // MARK: - Internals

    /** Bind every property to the internal jitter */
    internal func bindAll() {
        amplitude       .bind(&jitter.memory.amp)
        minimumFrequency.bind(&jitter.memory.cpsMin)
        maximumFrequency.bind(&jitter.memory.cpsMax)
    }

    /** Internal set up function */
    internal func setup() {
        sp_jitter_create(&jitter)
        sp_jitter_init(AKManager.sharedManager.data, jitter)
    }

    /** Computation of the next value */
    override func compute() {
        sp_jitter_compute(AKManager.sharedManager.data, jitter, nil, &leftOutput);
        rightOutput = leftOutput
    }

    /** Release of memory */
    override func teardown() {
        sp_jitter_destroy(&jitter)
    }
}
