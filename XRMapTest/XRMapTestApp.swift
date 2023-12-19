//
//  XRStripTestApp.swift
//  XRStripTest
//
//  Created by Michael A Edgcumbe on 6/23/23.
//

import SwiftUI

@main
struct XRMapTestApp: App {
    @State private var isSpaceHidden = true
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var currentStyle: ImmersionStyle = .mixed
    @StateObject var animationParameters = HSVAnimation(lightCount: GridSpaceView.stripLightCount, stripCount: GridSpaceView.stripCount, layerCount: GridSpaceView.stripLightLayerCount, numGrids: GridSpaceView.numGrids)
    var body: some Scene {
        WindowGroup(id:"LaunchView", content:{
            ContentView(isSpaceHidden: $isSpaceHidden)
        }).windowStyle(.plain)
        ImmersiveSpace(id: "StripSpace") {
            GridSpaceView(animationParameters: animationParameters)
        }.immersionStyle(selection:$currentStyle, in: .mixed, .progressive, .full)
    }
}
