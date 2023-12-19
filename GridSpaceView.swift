//
//  GridSpaceView.swift
//  XRMapTest
//
//  Created by Michael A Edgcumbe on 12/16/23.
//



import SwiftUI
import RealityKit
import RealityKitContent
import AudioKit

struct GridSpaceView: View {
    let rootEntity = AnchorEntity()
    @State private var mapEntities:[Entity] = [Entity]()
    static let audioEngineModel = AudioEngineModel()
    @StateObject private var audioModel = FFTModel(GridSpaceView.audioEngineModel.player)
    static let numGrids:Int = 2
    static let stripLightCount:Int = 60
    static let stripCount:Int = 10
    static let stripLightLayerCount = 3
    @ObservedObject var animationParameters:HSVAnimation
    static let allLightsCount = GridSpaceView.stripLightCount * GridSpaceView.stripLightLayerCount * GridSpaceView.stripCount
    let scaleMiddleLayer:Float = 10

    var body: some View {
        RealityView { content in
            content.add(rootEntity)
            for gridIndex in 0..<GridSpaceView.numGrids {
                do {
                    let entity = try await Entity(named: "Grid", in:realityKitContentBundle)
                    entity.name = "Grid"
                    //entity.transform.translation = SIMD3(Float(gridIndex) * 0.1625,0,0)
                    entity.transform.scale = SIMD3(100,100,100)
                    entity.transform.translation = SIMD3(0,0,Float(gridIndex*100))
                    mapEntities.append(entity)
                } catch {
                    print(error)
                }
                
                
            }
            
            for entity in mapEntities {
                rootEntity.addChild(entity)
                print("Adding \(entity.name) to root")
            }
            rootEntity.transform.translation = SIMD3(0,0.5,-5)
            print("Finished Building")
        }
        .onAppear(perform: {
            Task { @MainActor in
                try GridSpaceView.audioEngineModel.engine.start()
                GridSpaceView.audioEngineModel.player.play()
            }
            audioModel.onAppear()
        })
        .onChange(of: animationParameters.lightOffset, { oldValue, newValue in
            for gridIndex in 0..<mapEntities.count {
                for stripIndex in 0..<GridSpaceView.stripCount {
                        for layerIndex in 0..<GridSpaceView.stripLightLayerCount {
                            for lightIndex in 0..<GridSpaceView.stripLightCount {

                        let lightAddress = 180 * stripIndex + 60 * layerIndex + lightIndex
                        guard let lightEntity = mapEntities[gridIndex].findEntity(named: "Light_\(lightIndexString(index:lightAddress))")
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
                            
                            var displacement = animationParameters.lightOffset[gridIndex][stripIndex][lightIndex][layerIndex]
                            let layerAddress = floor(Float(lightAddress % GridSpaceView.stripLightLayerCount))
                            if layerAddress == 1 {
                                lightEntity.setScale(SIMD3(1,scaleMiddleLayer,1), relativeTo: nil)
                                displacement.y = displacement.y * layerAddress / Float(GridSpaceView.stripLightLayerCount) / scaleMiddleLayer
                            } else {
                                displacement.y = displacement.y * layerAddress / Float(GridSpaceView.stripLightLayerCount)
                            }

                            try shaderGraphMaterial.setParameter(name: "HSVAdjustment", value: .simd3Float(animationParameters.hsv[gridIndex][stripIndex][lightIndex][layerIndex]))
                            
                            if layerAddress != 0 {
                                try shaderGraphMaterial.setParameter(name: "ModelOffset", value: .simd3Float(displacement))
                            }
                            
                            modelComponent.materials = [shaderGraphMaterial]
                            lightEntity.components.set(modelComponent)

                            
                        } catch {
                            print(error)
                        }
                    }
                }
            }
            }
        })
        .onChange(of: animationParameters.displayLinkTimestamp) { oldValue, newValue in
            guard !mapEntities.isEmpty else {
                return
            }
                                
            let lightOffset = animationParameters.lightOffset
            guard lightOffset.count == GridSpaceView.numGrids else {
                return
            }

            for gridIndex in 0..<GridSpaceView.numGrids {
                for stripIndex in 0..<GridSpaceView.stripCount {
                    for lightIndex in 0..<GridSpaceView.stripLightCount {
                        for layerIndex in 0..<GridSpaceView.stripLightLayerCount {
                            do {
                                try animationParameters.setSaturation(to:abs( lightOffset[gridIndex][stripIndex][lightIndex][layerIndex].y), for: stripIndex, lightIndex: lightIndex, gridIndex:gridIndex)
                                try animationParameters.setHue(to:abs( lightOffset[gridIndex][stripIndex][lightIndex][layerIndex].y), for: stripIndex, lightIndex:lightIndex, gridIndex:gridIndex)
                            } catch {
                                print(error)
                            }
                        }
                    }
                }
            }
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
    let animationParameters = HSVAnimation(lightCount:GridSpaceView.stripLightCount, stripCount:GridSpaceView.stripCount, layerCount: GridSpaceView.stripLightLayerCount, numGrids: 1)
    return GridSpaceView(animationParameters: animationParameters)
}
