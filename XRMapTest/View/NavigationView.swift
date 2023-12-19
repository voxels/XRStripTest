//
//  NavigationView.swift
//  XRStripTest
//
//  Created by Michael A Edgcumbe on 12/2/23.
//

import SwiftUI

struct NavigationView: View {
    @Binding var isSpaceHidden:Bool
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        NavigationStack {
            VStack() {
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
}

#Preview {
    NavigationView(isSpaceHidden: .constant(false))
}
