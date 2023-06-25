//
//  MenuView.swift
//  XRStripTest
//
//  Created by Michael A Edgcumbe on 6/24/23.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct MainMenuView: View {
    @Binding var isSpaceHidden:Bool
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    var body: some View {
        NavigationStack {
            ZStack{
                Button("View Model") {
                    Task {
                        let result = await openImmersiveSpace(id: "StripSpace")
                        switch result {
                        case .opened:
                            isSpaceHidden = false
                        case .error:
                            break
                        case .userCancelled:
                            break
                        @unknown default:
                            fatalError()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    MainMenuView(isSpaceHidden: .constant(true))
}
