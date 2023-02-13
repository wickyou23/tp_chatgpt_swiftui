//
//  TPGPTLoading.swift
//  TPChatGPT
//
//  Created by Thang Phung on 09/02/2023.
//

import Foundation
import SwiftUI

struct TPGPTLoading: View {
    @State var isAnimating = false
    @State var isAnimating2 = false
    @State var isAnimating3 = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .frame(width: 6, height: 6)
                .animation(Animation.linear.repeatForever(autoreverses: true).speed(0.5), value: isAnimating)
                .offset(y: isAnimating ? -2 : 2)
            Circle()
                .frame(width: 6, height: 6)
                .animation(Animation.linear.repeatForever(autoreverses: true).speed(0.5), value: isAnimating2)
                .offset(y: isAnimating2 ? -2 : 2)
            Circle()
                .frame(width: 6, height: 6)
                .animation(Animation.linear.repeatForever(autoreverses: true).speed(0.5), value: isAnimating3)
                .offset(y: isAnimating3 ? -2 : 2)
        }
        .padding(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
        .background(Color.green)
        .cornerRadius(12)
        .frame(height: 24)
        
        .onAppear {
            isAnimating = true
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
                isAnimating2 = true
            }

            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
                isAnimating3 = true
            }
        }
        .onDisappear {
            isAnimating = false
            isAnimating2 = false
            isAnimating3 = false
        }
    }
}

struct TPGPTLoading_Previews: PreviewProvider {
    static var previews: some View {
        TPGPTLoading()
    }
}
