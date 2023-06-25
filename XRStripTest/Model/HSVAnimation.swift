//
//  LightColorAnimation.swift
//  XRStripTest
//
//  Created by Michael A Edgcumbe on 6/25/23.
//

import SwiftUI

public enum HSVAnimationError : Error {
    case RequiresNormalizedValue
    case OutOfBounds
}

class HSVAnimation : ObservableObject {
    @Published var hsv:[SIMD3<Float>] = [SIMD3<Float>]()
    @Published var targetHueDuration = [CFTimeInterval]()
    @Published var targetSaturationDuration = [CFTimeInterval]()
    @Published var targetBrightnessDuration = [CFTimeInterval]()
    @Published var targetHue = [Float]()
    @Published var targetSaturation = [Float]()
    @Published var targetBrightness = [Float]()
    @Published var originHue = [Float]()
    @Published var originSaturation = [Float]()
    @Published var originBrightness = [Float]()
    @Published var hueAnimationStartTime = [CFTimeInterval]()
    @Published var saturationAnimationStartTime = [CFTimeInterval]()
    @Published var brightnessAnimationStartTime = [CFTimeInterval]()
    
    private var displayLink:CADisplayLink!
    private var frameTimeInterval:CFTimeInterval = 1.0/60.0
    
    init(count:Int) {
        hsv = Array(repeating: SIMD3(0, 1, 1), count: count)
        targetHueDuration = Array(repeating: 1, count: count)
        targetSaturationDuration = Array(repeating: 1, count: count)
        targetBrightnessDuration = Array(repeating: 1, count: count)
        targetHue = Array(repeating: 0, count: count)
        targetSaturation = Array(repeating: 1, count: count)
        targetBrightness = Array(repeating: 1, count: count)
        originHue = Array(repeating: 0, count: count)
        originSaturation = Array(repeating: 1, count: count)
        originBrightness = Array(repeating: 1, count: count)
        hueAnimationStartTime = Array(repeating: CACurrentMediaTime(), count: count)
        saturationAnimationStartTime = Array(repeating: CACurrentMediaTime(), count: count)
        brightnessAnimationStartTime = Array(repeating: CACurrentMediaTime(), count: count)
        createDisplayLink()
    }
    
    public func setHue(to target:Float, for index:Int) throws {
        if target < 0 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard index < hsv.count, index < originHue.count, index < targetHue.count, index < targetHueDuration.count else {
            throw HSVAnimationError.OutOfBounds
        }
        
        hsv[index].x = target
        originHue[index] = target
        targetHue[index] = target
        targetHueDuration[index] = 0
    }
    
    public func setSaturation(to target:Float, for index:Int) throws {
        if target < 0 || target > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard index < hsv.count, index < originSaturation.count, index < targetSaturation.count, index < targetSaturationDuration.count else {
            throw HSVAnimationError.OutOfBounds
        }
        
        hsv[index].y = target
        originSaturation[index] = target
        targetSaturation[index] = target
        targetSaturationDuration[index] = 0
    }
    
    public func setBrightness(to target: Float, for index:Int) throws {
        if target < 0 || target > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard index < hsv.count, index < originBrightness.count, index < targetBrightness.count, index < targetBrightnessDuration.count else {
            throw HSVAnimationError.OutOfBounds
        }

        hsv[index].z = target
        originBrightness[index] = target
        targetBrightness[index] = target
        targetBrightnessDuration[index] = 0
    }
    
    public func animateHue(to target:Float, duration:CFTimeInterval, for index:Int) throws {
        if target < 0 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard index < targetHue.count, index < originHue.count, index < targetHueDuration.count, index < hueAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }
        
        originHue[index] = hsv[index].x
        targetHue[index] = target
        targetHueDuration[index] = duration
        hueAnimationStartTime[index] = CACurrentMediaTime()
    }
    
    public func animateSaturation(to target:Float, duration:CFTimeInterval, for index:Int) throws {
        if target < 0 || target > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard index < targetSaturation.count, index < originSaturation.count, index < targetSaturationDuration.count, index < saturationAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }

        originSaturation[index] = hsv[index].y
        targetSaturation[index] = target
        targetSaturationDuration[index] = duration
        saturationAnimationStartTime[index] = CACurrentMediaTime()
    }
    
    public func animateBrightness(to target:Float, duration:CFTimeInterval, for index:Int) throws {
        if target < 0 || target > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard index < targetBrightness.count, index < originBrightness.count, index < targetBrightnessDuration.count, index < brightnessAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }

        originBrightness[index] = hsv[index].z
        targetBrightness[index] = target
        targetBrightnessDuration[index] = duration
        brightnessAnimationStartTime[index] = CACurrentMediaTime()
    }
    
    public func adjustHue(by increment:Float, duration:CFTimeInterval, for index:Int) throws {
        if increment < -1 || increment > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard index < hsv.count, index < originHue.count, index < targetHue.count, index < targetHueDuration.count, index < hueAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }

        originHue[index] = hsv[index].x
        targetHue[index] = originHue[index] + increment
        if targetHue[index] > 1 {
            targetHue[index] = (originHue[index] + increment).truncatingRemainder(dividingBy: 1)
        } else if targetHue[index] < 0 {
            targetHue[index] = 1 - targetHue[index]
        }
        targetHueDuration[index] = duration
        hueAnimationStartTime[index] = CACurrentMediaTime()
    }
    
    public func adjustSaturation(by increment:Float, duration:CFTimeInterval, for index:Int) throws {
        if increment < -1 || increment > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard index < hsv.count, index < originSaturation.count, index < targetSaturation.count, index < targetSaturationDuration.count, index < saturationAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }

        originSaturation[index] = hsv[index].y
        targetSaturation[index] = min(1,max(0,(originSaturation[index] + increment).truncatingRemainder(dividingBy: 1)))
        targetSaturationDuration[index] = duration
        saturationAnimationStartTime[index] = CACurrentMediaTime()
    }
    
    public func adjustBrightness(by increment:Float, duration:CFTimeInterval, for index:Int) throws {
        if increment < -1 || increment > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard index < hsv.count, index < originBrightness.count, index < targetBrightness.count, index < targetBrightnessDuration.count, index < brightnessAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }
        
        originBrightness[index] = hsv[index].z
        targetBrightness[index] = min(1,max(0,(originBrightness[index] + increment).truncatingRemainder(dividingBy: 1)))
        targetBrightnessDuration[index] = duration
        brightnessAnimationStartTime[index] = CACurrentMediaTime()
    }
}

extension HSVAnimation {
    func nextIncrement(to targetValue:Float, currentValue:Float, originValue:Float, duration:CFTimeInterval, frameTimeInterval:CFTimeInterval) -> Float {
        if targetValue == currentValue {
            return 0
        }
        
        let remainingValue = Double(targetValue - originValue)

        let valuePerFrame = frameTimeInterval / duration * remainingValue
        
        return Float(valuePerFrame)
    }
    
    func calculateHSV(startValue:SIMD3<Float>, incrementHue:Float, incrementSaturation:Float, incrementBrightness:Float) -> SIMD3<Float> {
        let currentHue = startValue.x + incrementHue
        let currentSaturation = startValue.y + incrementSaturation
        let currentBrightness = startValue.z + incrementBrightness
        
        return SIMD3(currentHue, currentSaturation, currentBrightness)
    }
}


extension HSVAnimation {
    private func createDisplayLink() {
        displayLink = CADisplayLink(target: self, selector:#selector(onFrame(link:)))
        displayLink.add(to: .main, forMode: .default)
    }
}

extension HSVAnimation {
    @objc func onFrame(link:CADisplayLink) {
        frameTimeInterval = link.targetTimestamp - link.timestamp
        for index in 0..<hsv.count {
            let incrementHue = nextIncrement(to: targetHue[index], currentValue: hsv[index].x, originValue: originHue[index], duration: targetHueDuration[index], frameTimeInterval: frameTimeInterval)
            let incrementSaturation = nextIncrement(to: targetSaturation[index], currentValue: hsv[index].y, originValue: originSaturation[index], duration: targetSaturationDuration[index], frameTimeInterval: frameTimeInterval)
            let incrementBrightness = nextIncrement(to: targetBrightness[index], currentValue: hsv[index].z, originValue: originBrightness[index], duration: targetBrightnessDuration[index], frameTimeInterval: frameTimeInterval)
            hsv[index] = calculateHSV(startValue:hsv[index], incrementHue: incrementHue, incrementSaturation: incrementSaturation, incrementBrightness: incrementBrightness)
        }
    }
}
