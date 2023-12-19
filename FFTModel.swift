// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKitUI/

import Accelerate
import AudioKit
import SwiftUI

open class FFTModel: ObservableObject {
    @Published public var amplitudes: [Float?] = Array(repeating: nil, count: 50)
    public var nodeTap: FFTTap!
    public var defaultMaxAmplitude: Float = 0.0
    public var defaultMinAmplitude: Float = -70.0
    public var referenceValueForFFT: Float = 12.0
    public var node: Node

    private var linearGradient: LinearGradient
    private var paddingFraction: CGFloat
    private var includeCaps: Bool
    private var barCount: Int
    private var fftValidBinCount: FFTValidBinCount?
    private var minAmplitude: Float
    private var maxAmplitude: Float
    private let defaultBarCount: Int = 8
    private let maxBarCount: Int = 128
    private var backgroundColor: Color

    public init(_ node: Node,
                linearGradient: LinearGradient = LinearGradient(gradient: Gradient(colors: [.red, .yellow, .green]),
                                                                startPoint: .top,
                                                                endPoint: .center),
                paddingFraction: CGFloat = 0.2,
                includeCaps: Bool = true,
                validBinCount: FFTValidBinCount? = nil,
                barCount: Int? = nil,
                maxAmplitude: Float = -10.0,
                minAmplitude: Float = -150.0,
                backgroundColor: Color = Color.black)
    {
        self.node = node
        self.linearGradient = linearGradient
        self.paddingFraction = paddingFraction
        self.includeCaps = includeCaps
        self.maxAmplitude = maxAmplitude
        self.minAmplitude = minAmplitude
        fftValidBinCount = validBinCount
        self.backgroundColor = backgroundColor

        if maxAmplitude < minAmplitude {
            fatalError("Maximum amplitude cannot be less than minimum amplitude")
        }
        if minAmplitude > 0.0 || maxAmplitude > 0.0 {
            fatalError("Amplitude values must be less than zero")
        }

        if let requestedBarCount = barCount {
            self.barCount = requestedBarCount
        } else {
            if let fftBinCount = fftValidBinCount {
                if Int(fftBinCount.rawValue) > maxBarCount - 1 {
                    self.barCount = maxBarCount
                } else {
                    self.barCount = Int(fftBinCount.rawValue)
                }
            } else {
                self.barCount = defaultBarCount
            }
        }
    }
    
    func updateNode(_ node: Node, fftValidBinCount: FFTValidBinCount? = nil) {
        if node !== self.node {
            self.node = node
            nodeTap = FFTTap(node, fftValidBinCount: fftValidBinCount, callbackQueue: .main) { fftData in
                self.updateAmplitudes(fftData)
            }
            nodeTap.isNormalized = false
            nodeTap.start()
        } else {
            nodeTap = FFTTap(node, fftValidBinCount: fftValidBinCount, callbackQueue: .main) { fftData in
                self.updateAmplitudes(fftData)
            }
            nodeTap.isNormalized = false
            nodeTap.start()

        }
    }

    func updateAmplitudes(_ fftFloats: [Float]) {
        var fftData = fftFloats
        for index in 0 ..< fftData.count {
            if fftData[index].isNaN { fftData[index] = 0.0 }
        }

        var one = Float(1.0)
        var zero = Float(0.0)
        var decibelNormalizationFactor = Float(1.0 / (maxAmplitude - minAmplitude))
        var decibelNormalizationOffset = Float(-minAmplitude / (maxAmplitude - minAmplitude))

        var decibels = [Float](repeating: 0, count: fftData.count)
        vDSP_vdbcon(fftData, 1, &referenceValueForFFT, &decibels, 1, vDSP_Length(fftData.count), 0)

        vDSP_vsmsa(decibels,
                   1,
                   &decibelNormalizationFactor,
                   &decibelNormalizationOffset,
                   &decibels,
                   1,
                   vDSP_Length(decibels.count))

        vDSP_vclip(decibels, 1, &zero, &one, &decibels, 1, vDSP_Length(decibels.count))

        // swap the amplitude array
        self.amplitudes = decibels
    }

    func mockAudioInput() {
        var mockFloats = [Float]()
        for _ in 0...65 {
            mockFloats.append(Float.random(in: 0...0.1))
        }
        updateAmplitudes(mockFloats)
        let waitTime: TimeInterval = 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
            self.mockAudioInput()
        }
    }
    
    func onAppear(node:Node) {
        
        updateNode(node, fftValidBinCount: self.fftValidBinCount)
        maxAmplitude = self.defaultMaxAmplitude
        minAmplitude = self.defaultMinAmplitude
    }
}
