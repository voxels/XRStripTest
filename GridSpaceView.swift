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
    @State private var scaleMiddleLayer:Float = 10
    
    var body: some View {
        RealityView { content in
            content.add(rootEntity)
            for gridIndex in 0..<GridSpaceView.numGrids {
                do {
                    let entity = try await Entity(named: "Grid", in:realityKitContentBundle)
                    entity.name = "Grid"
//                    entity.transform.translation = SIMD3(Float(gridIndex) * 0.1625,0,0)
//                    entity.transform.scale = SIMD3(100,25,100)
                    entity.transform.translation = SIMD3(0,0,Float(gridIndex))
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
            audioModel.onAppear(node:GridSpaceView.audioEngineModel.player)
        })
        .onChange(of: animationParameters.displayLinkTimestamp, { oldValue, newValue in
            guard animationParameters.lightOffset.count == GridSpaceView.numGrids else {
                return
            }
            
            animationParameters.resetOffset(with:audioModel.amplitudes, lightCount: GridSpaceView.stripLightCount, stripCount: GridSpaceView.stripCount, gridCount: GridSpaceView.numGrids)

            for gridIndex in 0..<GridSpaceView.numGrids {
                for stripIndex in 0..<GridSpaceView.stripCount {
                    for lightIndex in 0..<GridSpaceView.stripLightCount {
                                do {
                                    if stripIndex == 0 {
                                        try animationParameters.setBrightness(to:Float( animationParameters.offsetRandomness[gridIndex][stripIndex][lightIndex]), for: stripIndex, lightIndex: lightIndex, gridIndex:gridIndex)
                                        try animationParameters.setSaturation(to:0, for: stripIndex, lightIndex: lightIndex, gridIndex:gridIndex)
                                    } else {
                                        try animationParameters.setHue(to:1.0 - 0.05 * Float((GridSpaceView.stripCount - stripIndex)), for: stripIndex, lightIndex: lightIndex, gridIndex:gridIndex)
                                        try animationParameters.setSaturation(to:0.1 * Float((GridSpaceView.stripCount - stripIndex)), for: stripIndex, lightIndex: lightIndex, gridIndex:gridIndex)
                                        try animationParameters.setBrightness(to:0.1 * Float((GridSpaceView.stripCount - stripIndex)), for: stripIndex, lightIndex:lightIndex, gridIndex:gridIndex)
                                    }
                                } catch {
                                    print(error)
                                }
                    }
                }
            }
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
                                var displacement = newValue[gridIndex][stripIndex][lightIndex][layerIndex]
                                
                                displacement.y = displacement.y * Float(layerIndex) / Float(GridSpaceView.stripLightLayerCount)

                                if stripIndex == 0 {
                                    lightEntity.transform.scale = SIMD3(1,5,1)
                                    displacement.y /= 5
                                }

                                try shaderGraphMaterial.setParameter(name: "HSVAdjustment", value: .simd3Float(animationParameters.hsv[gridIndex][stripIndex][lightIndex][layerIndex]))
                                
                                try shaderGraphMaterial.setParameter(name: "ModelOffset", value: .simd3Float(displacement))
                                
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
