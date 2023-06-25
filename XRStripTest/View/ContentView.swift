//
//  ContentView.swift
//  XRStripTest
//
//  Created by Michael A Edgcumbe on 6/23/23.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @Binding var isSpaceHidden:Bool
    var body: some View {
        if isSpaceHidden {
            MainMenuView(isSpaceHidden: $isSpaceHidden)
        } else {
            StripSpaceMenu(isSpaceHidden: $isSpaceHidden)
        }
    }
}

#Preview {
    ContentView(isSpaceHidden: .constant(false))
}
