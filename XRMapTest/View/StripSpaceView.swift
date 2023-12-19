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
    let rootEntity = AnchorEntity()
    @State private var mapEntities:[Entity] = [Entity]()
    static let stripLightLayerCount = 1
    static let stripLightCount:Int = 60
    static let stripCount:Int = 60
    static let cloneCount:Int = 1
    @ObservedObject var animationParameters:HSVAnimation

    @State private var initColors:Bool = false
    var body: some View {
        RealityView { content in
            content.add(rootEntity)
            Task {
                do {
                    for stripIndex in 0..<StripSpaceView.stripCount {
                        let entity = try await Entity(named: "Strip", in:realityKitContentBundle)
                        entity.name = "Strip_\(stripIndex)"
                        let angleRadians:Double = Angle(degrees: Double(stripIndex) * 360.0 / Double(StripSpaceView.stripCount) - 90.0).radians
                        entity.setOrientation(.init(angle: Float(angleRadians), axis: SIMD3(0,1,0)), relativeTo: nil)
//                        entity.transform.translation = SIMD3(Float(0.5 * sin(Angle(degrees: Double(stripIndex) * 360.0 / Double(StripSpaceView.stripCount)).radians)),0,Float(0.5 * cos(Angle(degrees: Double(stripIndex) * 360.0 / Double(StripSpaceView.stripCount)).radians)))
                        for lightIndex in 0..<StripSpaceView.stripLightCount {
                            guard let lightEntity = entity.findEntity(named: "Light_\(lightIndexString(index:lightIndex))")
                            else {
                                print("Did not find light \(lightIndexString(index: lightIndex))")
                                return
                            }
                            
                            massClone(entity: lightEntity, index: lightIndex)
                        }
                        mapEntities.append(entity)
                    }
                    
                    for entity in mapEntities {
                        rootEntity.addChild(entity)
                        print("Adding \(entity.name) to root")
                    }
                    
                    rootEntity.transform.translation = SIMD3(0,0.5,-5)
                    
                    print("Finished Building")
                } catch {
                    print(error)
                }
            }
        }
        .onChange(of: animationParameters.hsv) { oldValue, newValue in
            guard mapEntities.count == StripSpaceView.stripCount  else {
                print("Did not find strip entity")
                return
            }
            for gridIndex in 0..<1 {
                for layerIndex in 0..<StripSpaceView.stripLightLayerCount {
                    for stripIndex in 0..<newValue.count {
                        for lightIndex in 0..<StripSpaceView.stripLightCount {
                            
                            guard let lightEntity = mapEntities[stripIndex].findEntity(named: "Light_\(lightIndexString(index:lightIndex))")
                            else {
                                print("Did not find light \(lightIndexString(index: lightIndex))")
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
                                try shaderGraphMaterial.setParameter(name: "HSVAdjustment", value: .simd3Float(newValue[gridIndex][layerIndex][stripIndex][lightIndex]))
                                try shaderGraphMaterial.setParameter(name: "ModelOffset", value: .simd3Float(animationParameters.lightOffset[gridIndex][layerIndex][stripIndex][lightIndex]))
                                modelComponent.materials = [shaderGraphMaterial]
                                lightEntity.components.set(modelComponent)
                                
                                for cloneIndex in 0..<lightEntity.children.count {
                                    let child = lightEntity.children[cloneIndex]
                                    
                                    let yPos:Float = Float(cloneIndex) / Float(lightEntity.children.count) * animationParameters.lightOffset[gridIndex][layerIndex][stripIndex][lightIndex].y
                                    
                                    child.setPosition(SIMD3(0,yPos,0), relativeTo: lightEntity)
                                    let xValue:Float = 2.0 * Float.pi * Float(lightIndex) / Float(StripSpaceView.stripLightCount)
                                    
                                    lightEntity.scale = SIMD3(xValue,1,1)
                                    
                                    guard var lightModelComponent = child.components[ModelComponent.self] else {
                                        print("Did not find model component")
                                        continue
                                    }
                                    
                                    guard var lightShaderGraphMaterial = lightModelComponent.materials.first as? ShaderGraphMaterial else {
                                        print("Did not find shader graph material")
                                        continue
                                    }
                                    
                                    do {
                                        try lightShaderGraphMaterial.setParameter(name: "HSVAdjustment", value: .simd3Float(SIMD3(1,0,0)))
                                    } catch {
                                        print(error)
                                    }
                                    
                                    lightModelComponent.materials = [lightShaderGraphMaterial]
                                    child.components.set(lightModelComponent)
                                }
                                
                            } catch {
                                print(error)
                            }
                        }
                    }
                }
            }
        }.onChange(of: animationParameters.displayLinkTimestamp) { oldValue, newValue in
            
            guard !mapEntities.isEmpty else {
                return
            }
            
            Task {
                //                if !initColors {
                //                    initColors.toggle()
                //                }
                for gridIndex in 0..<1 {
                    for layerIndex in 0..<StripSpaceView.stripLightLayerCount {
                        for stripIndex in 0..<StripSpaceView.stripCount{
                            for lightIndex in 0..<StripSpaceView.stripLightCount {
                                do {
                                    try animationParameters.setSaturation(to:abs( animationParameters.lightOffset[gridIndex][layerIndex][stripIndex][lightIndex].y * 0.5), for: stripIndex, lightIndex: lightIndex, gridIndex:gridIndex)
                                    try animationParameters.setHue(to:abs( animationParameters.lightOffset[gridIndex][layerIndex] [stripIndex][lightIndex].y * 0.5), for: stripIndex, lightIndex:lightIndex, gridIndex:gridIndex)
                                } catch {
                                    print(error)
                                }
                            }
                            let stripEntity = mapEntities[stripIndex]
                            let angleRadians:Double = Angle(degrees: Double(stripIndex) * 360.0 / Double(StripSpaceView.stripCount) - 90.0).radians
                            let originalOrientation = simd_quatf(angle: Float(angleRadians), axis: SIMD3(0,1,0))
                            let addOrientation = simd_quatf(angle: Float(1.0 * animationParameters.displayLinkTimestamp), axis: SIMD3(0,1,0))
                            let orientation = simd_add(originalOrientation, addOrientation)
                            
                            stripEntity.setOrientation(orientation, relativeTo:nil)
                        }
                    }
                }
            }
        }.onChange(of: initColors) { oldValue, newValue in
            if newValue, newValue != oldValue {
                Task { 
                    for stripIndex in 0..<StripSpaceView.stripLightCount {
                        
                    for lightIndex in 0..<StripSpaceView.stripLightCount {
                        let startColor:Float = Float(lightIndex) / Float(StripSpaceView.stripLightCount)
                        do {
                            try animationParameters.setHue(to: startColor, for: stripIndex, lightIndex:lightIndex, gridIndex:0)
                        } catch {
                            print(error)
                        }
                    }
                }
                }

            }
        }.onAppear {
            animationParameters.resetOffset(lightCount: StripSpaceView.stripLightCount, stripCount: StripSpaceView.stripCount, gridCount: 1)
        }
    }
    
    func massClone(entity:Entity, index:Int) {
        for threshIndex in 0..<StripSpaceView.cloneCount {
            let clone = entity.clone(recursive: false)
            clone.name = "Clone_\(index)_\(threshIndex)"
//            clone.setOrientation(.init(angle: Float(Angle(degrees: 90).radians), axis: SIMD3(0,1,0)), relativeTo: nil)
            clone.setPosition(SIMD3(0,0,0), relativeTo: nil)
            entity.addChild(clone)
            print("Did add clone \(clone.name)")
        }
    }
    
    func lightIndexString(index:Int)->String{
        var lightIndexString = "\(index + 1)"
        if lightIndexString.count == 1 {
            lightIndexString = "00\(lightIndexString)"
        } else if lightIndexString.count == 2 {
            lightIndexString = "0\(lightIndexString)"
        }
        return lightIndexString
    }
}



#Preview {
    let animationParameters = HSVAnimation(lightCount:StripSpaceView.stripLightCount, stripCount:StripSpaceView.stripCount, layerCount: StripSpaceView.stripLightLayerCount, numGrids: 1)
    return StripSpaceView(animationParameters: animationParameters)
}
