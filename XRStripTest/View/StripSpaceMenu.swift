//
//  StripSpaceMenu.swift
//  XRStripTest
//
//  Created by Michael A Edgcumbe on 6/24/23.
//

import SwiftUI

struct StripSpaceMenu: View {
    @Binding var isSpaceHidden:Bool
    @Environment (\.dismissImmersiveSpace) private var dismissImmersiveSpace
    var body: some View {
        ZStack {
            Button("Dismiss Space") {
                Task {
                    await dismissImmersiveSpace()
                    isSpaceHidden = true
                }
            }
        }
    }
}

#Preview {
    StripSpaceMenu(isSpaceHidden: .constant(false))
}
