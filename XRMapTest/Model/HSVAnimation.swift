//
//  LightColorAnimation.swift
//  XRStripTest
//
//  Created by Michael A Edgcumbe on 6/25/23.
//

import SwiftUI
import GameplayKit

public enum HSVAnimationError : Error {
    case RequiresNormalizedValue
    case OutOfBounds
}

class HSVAnimation : ObservableObject {
    @Published public var hsv:[[[[SIMD3<Float>]]]] = [[[[SIMD3<Float>]]]]()
    @Published var displayLinkTimestamp:Double = 0
    @Published var lightOffset:[[[[SIMD3<Float>]]]] = [[[[SIMD3<Float>]]]]()

    var targetHueDuration = [[[CFTimeInterval]]]()
    var targetSaturationDuration = [[[CFTimeInterval]]]()
    var targetBrightnessDuration = [[[CFTimeInterval]]]()
    var targetHue = [[[Float]]]()
    var targetSaturation = [[[Float]]]()
    var targetBrightness = [[[Float]]]()
    var originHue = [[[Float]]]()
    var originSaturation = [[[Float]]]()
    var originBrightness = [[[Float]]]()
    var hueAnimationStartTime = [[[CFTimeInterval]]]()
    var saturationAnimationStartTime = [[[CFTimeInterval]]]()
    var brightnessAnimationStartTime = [[[CFTimeInterval]]]()
    private var frameTimeInterval:Double = 1.0/60.0
    var offsetRandomness:[[[Double]]] = [[[Double]]]()
    var lastOffsetRandomness:[[[Double]]] = [[[Double]]]()
    var lastOffsetReset:Double = 0
    var lightLayerCount:Int
    var stripCount:Int
    var lightCount:Int
    var gridCount:Int
    
    private var displayLink:CADisplayLink!
    private var lastEffectiveTimestamp:Double = 0
    
    init(lightCount:Int, stripCount:Int, layerCount:Int, numGrids:Int) {
        hsv = Array(repeating:Array(repeating:Array(repeating: Array(repeating:SIMD3(0, 1, 1), count: layerCount), count: lightCount), count:stripCount), count:numGrids)
        targetHueDuration = Array(repeating:Array(repeating: Array(repeating: 1, count: lightCount), count: stripCount), count:numGrids)
        targetSaturationDuration = Array(repeating:Array(repeating: Array(repeating: 1, count: lightCount), count: stripCount), count:numGrids)
        targetBrightnessDuration = Array(repeating:Array(repeating: Array(repeating: 1, count: lightCount), count: stripCount), count:numGrids)
        targetHue = Array(repeating:Array(repeating: Array(repeating: 0, count: lightCount), count: stripCount), count:numGrids)
        targetSaturation = Array(repeating:Array(repeating: Array(repeating: 1, count: lightCount), count: stripCount), count:numGrids)
        targetBrightness = Array(repeating:Array(repeating: Array(repeating: 1, count: lightCount), count: stripCount), count:numGrids)
        originHue = Array(repeating:Array(repeating: Array(repeating: 0, count: lightCount), count: stripCount), count:numGrids)
        originSaturation = Array(repeating:Array(repeating: Array(repeating: 1, count: lightCount), count: stripCount), count:numGrids)
        originBrightness = Array(repeating:Array(repeating: Array(repeating: 1, count: lightCount), count: stripCount), count:numGrids)
        hueAnimationStartTime = Array(repeating:Array(repeating: Array(repeating: CACurrentMediaTime(), count: lightCount), count: stripCount), count:numGrids)
        saturationAnimationStartTime = Array(repeating:Array(repeating: Array(repeating: CACurrentMediaTime(), count: lightCount), count: stripCount), count:numGrids)
        brightnessAnimationStartTime = Array(repeating:Array(repeating: Array(repeating: CACurrentMediaTime(), count: lightCount), count: stripCount), count:numGrids)
        self.lightLayerCount = layerCount
        self.lightCount = lightCount
        self.stripCount = stripCount
        self.gridCount = numGrids
        self.lightOffset = Array(repeating:Array(repeating: Array(repeating: Array(repeating:SIMD3(0.0, 0.0, 0.0), count: layerCount), count:lightCount), count:stripCount), count:numGrids)
        
        resetOffset(lightCount: lightCount, stripCount: stripCount, gridCount: gridCount)
        lastOffsetRandomness = offsetRandomness
        createDisplayLink()
        
    }
    
    public func resetOffset(with amplitudes:[Float?], lightCount:Int, stripCount:Int, gridCount:Int) {
        guard amplitudes.count > gridCount * 60 + lightCount else {
            return
        }
        
        lastOffsetRandomness = offsetRandomness
        offsetRandomness.removeAll(keepingCapacity:true)
        for gridIndex in 0..<gridCount {
            var gridRandomness = [[Double]]()
            for stripIndex in 0..<stripCount {
                var values = [Double]()
                for lightIndex in 0..<lightCount {
                    if stripIndex == 0 {
                        let thisValue = Double(amplitudes[gridIndex * lightCount + lightIndex]!)
                        values.append(thisValue)
                    } else {
                        let thisValue = Double(lastOffsetRandomness[gridIndex][stripIndex-1][lightIndex])
                        values.append(thisValue)
                    }
                }
                gridRandomness.append(values)
            }
            if offsetRandomness.count == gridCount {
                offsetRandomness[gridIndex] = gridRandomness
            } else {
                offsetRandomness.append(gridRandomness)
            }
        }

        
        Task { @MainActor in
            var newLightOffset:[[[[SIMD3<Float>]]]] = Array(repeating:Array(repeating: Array(repeating: Array(repeating:SIMD3(0.0, 0.0, 0.0), count: lightLayerCount), count:lightCount), count:stripCount), count:gridCount)
            
            for gridIndex in 0..<self.gridCount {
                for stripIndex in 0..<self.stripCount {
                    for lightIndex in 0..<self.lightCount {
                        for layerIndex in 0..<self.lightLayerCount {
                            newLightOffset[gridIndex][stripIndex][lightIndex][layerIndex].y = Float(offsetRandomness[gridIndex][stripIndex][lightIndex])
                        }
                    }
                }
            }
    
            self.lightOffset = newLightOffset
        }
    }
    
    public func resetOffset(lightCount:Int, stripCount:Int, gridCount:Int) {
        offsetRandomness.removeAll()
        let noise = GKNoise(GKPerlinNoiseSource())
        noise.move(by: vector_double3(Double.random(in: 0..<100), Double.random(in: 0..<100), Double.random(in: 0..<100)))
        
        for gridIndex in 0..<gridCount {
            noise.move(by: vector_double3(Double(gridIndex)/Double(gridCount), 0, 0))
            let noiseMap = GKNoiseMap(noise)
            var gridRandomness = [[Double]]()
            for stripIndex in 0..<stripCount {
                var values = [Double]()
                let angleRadians:Double = Angle(degrees: Double(stripIndex) * 360.0 / Double(StripSpaceView.stripCount) - 180).radians
                for lightIndex in 0..<lightCount {
                    let lightIndexLength:Double = Double(lightIndex)
                    let xValue = Float(lightIndexLength * cos(angleRadians) + lightIndexLength)
                    let yValue = Float(lightIndexLength * sin(angleRadians) + lightIndexLength)
                    let thisValue = Double(noiseMap.interpolatedValue(at: vector_float2(xValue,yValue)))
                    values.append(thisValue)
                }
                gridRandomness.append(values)
            }
            offsetRandomness.append(gridRandomness)
        }
    }
    
    public func setHue(to target:Float, for stripIndex:Int, lightIndex:Int, gridIndex:Int) throws {
            var newTarget = target
            if target < 0 {
                newTarget = 0
            } else {
                newTarget = target
            }
            
            
            targetHue[gridIndex][stripIndex][lightIndex] = newTarget
            targetHueDuration[gridIndex][stripIndex][lightIndex] = displayLink.targetTimestamp
            hueAnimationStartTime[gridIndex][stripIndex][lightIndex] = CACurrentMediaTime()
        
    }
    
    public func setSaturation(to target:Float, for stripIndex:Int, lightIndex:Int, gridIndex:Int) throws {
            var newTarget = min(1,target)
            if target < 0 {
                newTarget = 0
            } else {
                newTarget = target
            }
            
            targetSaturation[gridIndex][stripIndex][lightIndex] = newTarget
            targetSaturationDuration[gridIndex][stripIndex][lightIndex] = displayLink.targetTimestamp
            hueAnimationStartTime[gridIndex][stripIndex][lightIndex] = CACurrentMediaTime()
    }
    
    public func setBrightness(to target: Float, for stripIndex:Int, lightIndex:Int, gridIndex:Int) throws {

        
        var newTarget = min(1,target)
            if target < 0 {
                newTarget = 0
            }
            
            targetBrightness[gridIndex][stripIndex][lightIndex] = newTarget
            targetBrightnessDuration[gridIndex][stripIndex][lightIndex] = displayLink.targetTimestamp
            hueAnimationStartTime[gridIndex][stripIndex][lightIndex] = CACurrentMediaTime()
    }
    
    public func animateHue(to target:Float, duration:CFTimeInterval, for stripIndex:Int, lightIndex:Int, gridIndex:Int) throws {
        if target < 0 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard stripIndex < targetHue.count, stripIndex < originHue.count, stripIndex < targetHueDuration.count, stripIndex < hueAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }
        
        Task {
            targetHue[gridIndex][stripIndex][lightIndex] = target
            targetHueDuration[gridIndex][stripIndex][lightIndex] = duration
            hueAnimationStartTime[gridIndex][stripIndex][lightIndex] = CACurrentMediaTime()
        }
    }
    
    public func animateSaturation(to target:Float, duration:CFTimeInterval, for stripIndex:Int, lightIndex:Int, gridIndex:Int) throws {
        if target < 0 || target > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard stripIndex < targetSaturation.count, stripIndex < originSaturation.count, stripIndex < targetSaturationDuration.count, stripIndex < saturationAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }
        
        Task {
            targetSaturation[gridIndex][stripIndex][lightIndex] = target
            targetSaturationDuration[gridIndex][stripIndex][lightIndex] = duration
            saturationAnimationStartTime[gridIndex][stripIndex][lightIndex] = CACurrentMediaTime()
        }
    }
    
    public func animateBrightness(to target:Float, duration:CFTimeInterval, for stripIndex:Int, lightIndex:Int, gridIndex:Int) throws {
        if target > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        
        guard stripIndex < targetBrightness.count, stripIndex < originBrightness.count, stripIndex < targetBrightnessDuration.count, stripIndex < brightnessAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }
        
        Task {
            var newTarget = target
            if target < 0 {
                newTarget = 0
            }
            
            targetBrightness[gridIndex][stripIndex][lightIndex] = newTarget
            targetBrightnessDuration[gridIndex][stripIndex][lightIndex] = duration
            brightnessAnimationStartTime[gridIndex][stripIndex][lightIndex] = CACurrentMediaTime()
        }
    }
    
    public func adjustHue(by increment:Float, duration:CFTimeInterval, stripIndex:Int, lightIndex:Int, layerIndex:Int, gridIndex:Int) throws {
        if increment < -1 || increment > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard stripIndex < stripCount, stripIndex < originHue.count, stripIndex < targetHue.count, stripIndex < targetHueDuration.count, stripIndex < hueAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }
        
        Task {
            originHue[gridIndex][stripIndex][lightIndex] = hsv[gridIndex][stripIndex][lightIndex][layerIndex].x
            targetHue[gridIndex][stripIndex][lightIndex] = originHue[gridIndex][stripIndex][lightIndex] + increment
            if targetHue[gridIndex][stripIndex][lightIndex] > 1 {
                targetHue[gridIndex][stripIndex][lightIndex] = (originHue[gridIndex][stripIndex][lightIndex] + increment).truncatingRemainder(dividingBy: 1)
            } else if targetHue[gridIndex][stripIndex][lightIndex] < 0 {
                targetHue[gridIndex][stripIndex][lightIndex] = 1 - targetHue[gridIndex][stripIndex][lightIndex]
            }
            targetHueDuration[gridIndex][stripIndex][lightIndex] = duration
            hueAnimationStartTime[gridIndex][stripIndex][lightIndex] = CACurrentMediaTime()
        }
    }
    
    public func adjustSaturation(by increment:Float, duration:CFTimeInterval, for stripIndex:Int, lightIndex:Int, layerIndex:Int, gridIndex:Int) throws {
        if increment < -1 || increment > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard stripIndex < stripCount, stripIndex < originSaturation.count, stripIndex < targetSaturation.count, stripIndex < targetSaturationDuration.count, stripIndex < saturationAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }
        
        Task {
            originSaturation[gridIndex][stripIndex][lightIndex] = hsv[gridIndex][stripIndex][lightIndex][layerIndex].y
            targetSaturation[gridIndex][stripIndex][lightIndex] = min(1,max(0,(originSaturation[gridIndex][stripIndex][lightIndex] + increment).truncatingRemainder(dividingBy: 1)))
            targetSaturationDuration[gridIndex][stripIndex][lightIndex] = duration
            saturationAnimationStartTime[gridIndex][stripIndex][lightIndex] = CACurrentMediaTime()
        }
    }
    
    public func adjustBrightness(by increment:Float, duration:CFTimeInterval, for stripIndex:Int, lightIndex:Int, layerIndex:Int, gridIndex:Int) throws {
        if increment < -1 || increment > 1 {
            throw HSVAnimationError.RequiresNormalizedValue
        }
        
        guard stripIndex < stripCount, stripIndex < originBrightness.count, stripIndex < targetBrightness.count, stripIndex < targetBrightnessDuration.count, stripIndex < brightnessAnimationStartTime.count else {
            throw HSVAnimationError.OutOfBounds
        }
        
        
        Task {
            originBrightness[gridIndex][stripIndex][lightIndex] = hsv[gridIndex][stripIndex][lightIndex][layerIndex].z
            targetBrightness[gridIndex][stripIndex][lightIndex] = min(1,max(0,(originBrightness[gridIndex][stripIndex][lightIndex] + increment).truncatingRemainder(dividingBy: 1)))
            targetBrightnessDuration[gridIndex][stripIndex][lightIndex] = duration
            brightnessAnimationStartTime[gridIndex][stripIndex][lightIndex] = CACurrentMediaTime()
        }
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
    private func calculateHSV(link:CADisplayLink)async ->[[[[SIMD3<Float>]]]] {
        
        let oldHsv = self.hsv
        let offsetRandomness = self.offsetRandomness
        let hue = self.originHue
        let saturation = self.originSaturation
        let brightness = self.originBrightness
        let targetHue = self.targetHue
        let targetSaturation = self.targetSaturation
        let targetBrightness = self.targetBrightness
        let targetHueDuration = self.targetHueDuration
        let targetSaturationDuration = self.targetSaturationDuration
        let targetBrightnessDuration = self.targetBrightnessDuration
        
        guard offsetRandomness.count == gridCount else {
            return oldHsv
        }

        let nextHsv = await withTaskGroup(of: (Int, Int, Int, Int, SIMD3<Float>).self, returning: [[[[SIMD3<Float>]]]].self, body: { taskGroup in
            var newHsv:[[[[SIMD3<Float>]]]] = Array(repeating:Array(repeating:Array(repeating: Array(repeating:SIMD3(0.0, 0.0, 1.0), count: lightLayerCount), count: lightCount), count:stripCount), count:gridCount)
            
            var newOriginHue:[[[Float]]] = Array(repeating:Array(repeating: Array(repeating: 0, count: lightCount), count: stripCount), count:gridCount)
            var newOriginSaturation:[[[Float]]] = Array(repeating:Array(repeating: Array(repeating: 0, count: lightCount), count: stripCount), count:gridCount)
            var newOriginBrightness:[[[Float]]] = Array(repeating:Array(repeating: Array(repeating: 0, count: lightCount), count: stripCount), count:gridCount)
            for gridIndex in 0..<self.gridCount {
                for stripIndex in 0..<self.stripCount {
                    for lightIndex in 0..<self.lightCount {
                        for layerIndex in 0..<self.lightLayerCount {
                            newOriginHue[gridIndex][stripIndex][lightIndex] = oldHsv[gridIndex][stripIndex][lightIndex][layerIndex].x
                            newOriginSaturation[gridIndex][stripIndex][lightIndex] = oldHsv[gridIndex][stripIndex][lightIndex][layerIndex].y
                            newOriginBrightness[gridIndex][stripIndex][lightIndex] = oldHsv[gridIndex][stripIndex][lightIndex][layerIndex].z
                            
                            taskGroup.addTask { [self] in
                                
                                let incrementHue = self.nextIncrement(to: targetHue[gridIndex][stripIndex][lightIndex], currentValue: oldHsv[gridIndex][stripIndex][lightIndex][layerIndex].x, originValue: hue[gridIndex][stripIndex][lightIndex], duration: targetHueDuration[gridIndex][stripIndex][lightIndex], frameTimeInterval: link.targetTimestamp)
                                let incrementSaturation = self.nextIncrement(to: targetSaturation[gridIndex][stripIndex][lightIndex], currentValue: oldHsv[gridIndex][stripIndex][lightIndex][layerIndex].y, originValue: saturation[gridIndex][stripIndex][lightIndex], duration: targetSaturationDuration[gridIndex][stripIndex][lightIndex], frameTimeInterval: link.targetTimestamp)
                                let incrementBrightness = self.nextIncrement(to: targetBrightness[gridIndex][stripIndex][lightIndex], currentValue: oldHsv[gridIndex][stripIndex][lightIndex][layerIndex].z, originValue: brightness[gridIndex][stripIndex][lightIndex], duration: targetBrightnessDuration[gridIndex][stripIndex][lightIndex], frameTimeInterval: link.targetTimestamp)
                                return (gridIndex, stripIndex, lightIndex, layerIndex,  self.calculateHSV(startValue:oldHsv[gridIndex][stripIndex][lightIndex][layerIndex], incrementHue: incrementHue, incrementSaturation: incrementSaturation, incrementBrightness: incrementBrightness))
                            }
                        }
                    }
                }
            }
            
            while let value = await taskGroup.next() {
                newHsv[value.0][value.1][value.2][value.3] = value.4
            }
            
            self.originHue =  newOriginHue
            self.originSaturation =  newOriginSaturation
            self.originBrightness =  newOriginBrightness
                        
            return newHsv
        })
        
        return nextHsv
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
        guard link.timestamp > lastEffectiveTimestamp + frameTimeInterval else {
            return
        }
        Task {
            let newHSV = await calculateHSV(link: link)
            Task { @MainActor in
                self.hsv = newHSV
            }
        }
        
        displayLinkTimestamp = link.timestamp
        lastEffectiveTimestamp = displayLinkTimestamp
    }
}
