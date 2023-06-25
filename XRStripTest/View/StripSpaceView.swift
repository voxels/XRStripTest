//
//  StripSpaceView.swift
//  XRStripTest
//
//  Created by Michael A Edgcumbe on 6/24/23.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct StripSpaceView: View {
    let rootEntity = Entity()
    static let stripLightCount:Int = 60
    static let animationDuration:TimeInterval = 2.0
    @StateObject var animationParameters = HSVAnimation(count:StripSpaceView.stripLightCount)
    let timer = Timer.publish(every: StripSpaceView.animationDuration, on: .main, in: .common).autoconnect()
    var body: some View {
        RealityView { content in
            content.add(rootEntity)
            do {
                let stripEntity = try await Entity(named: "Strip", in:realityKitContentBundle)
                
                stripEntity.setPosition([0,2.0,-1.5], relativeTo: rootEntity)
                rootEntity.addChild(stripEntity)
 
            } catch {
                print(error)
                fatalError()
            }
            Task {
                for index in 0..<StripSpaceView.stripLightCount {
                    let startColor:Float = Float(index) / Float(StripSpaceView.stripLightCount)
                    do {
                        try animationParameters.setHue(to: startColor, for: index)
                    } catch {
                        print(error)
                    }
                }
            }
        }.onChange(of: animationParameters.hsv) { oldValue, newValue in
            for index in 0..<newValue.count {
                guard let stripEntity = rootEntity.findEntity(named: "Strip") else {
                    print("Did not find strip entity")
                    return
                }
                
                var lightIndexString = "\(index + 1)"
                if lightIndexString.count == 1 {
                    lightIndexString = "00\(lightIndexString)"
                } else if lightIndexString.count == 2 {
                    lightIndexString = "0\(lightIndexString)"
                }
                
                guard let lightEntity = stripEntity.findEntity(named: "Light_\(lightIndexString)")
                else {
                    print("Did not find light \(lightIndexString)")
                    return
                }
                
                guard var modelComponent = lightEntity.components[ModelComponent.self] else {
                    print("Did not find model component")
                    return
                }
                            
                guard var shaderGraphMaterial = modelComponent.materials.first as? ShaderGraphMaterial else {
                    print("Did not find shader graph material")
                    return
                }
                
                do {
                    try shaderGraphMaterial.setParameter(name: "HSVAdjustment", value: .simd3Float(newValue[index]))
                    modelComponent.materials = [shaderGraphMaterial]
                    lightEntity.components.set(modelComponent)
                } catch {
                    print(error)
                }
            }
        }.onReceive(timer, perform: { _ in
            Task {
                for index in 0..<StripSpaceView.stripLightCount {
                    let startTime = animationParameters.hueAnimationStartTime[index]
                    let duration = animationParameters.targetHueDuration[index]
                    
                    if CACurrentMediaTime() > startTime + duration {
                        let currentHue = animationParameters.hsv[index].x
                        let endColor:Float = 1.0 + currentHue

                        do {
                            try animationParameters.animateHue(to: endColor, duration: StripSpaceView.animationDuration, for: index)
                        } catch {
                            print(error)
                        }
                    }
                }
            }
        })
    }
}

#Preview {
    StripSpaceView()
}
