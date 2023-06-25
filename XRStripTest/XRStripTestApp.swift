//
//  XRStripTestApp.swift
//  XRStripTest
//
//  Created by Michael A Edgcumbe on 6/23/23.
//

import SwiftUI

@main
struct XRStripTestApp: App {
    @State private var isSpaceHidden = true
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @State private var currentStyle: ImmersionStyle = .mixed
    var body: some Scene {
        WindowGroup(id:"LaunchView", content:{
            ContentView(isSpaceHidden: $isSpaceHidden).frame(width: 200, height:100, alignment: .center)
        }).windowStyle(.plain)
        ImmersiveSpace(id: "StripSpace") {
            StripSpaceView()
        }.immersionStyle(selection:$currentStyle, in: .mixed, .progressive, .full)
    }
}
