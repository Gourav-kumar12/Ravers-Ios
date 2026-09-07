//
//  LoadingScreen.swift
//  Ravers-ios
//
//  Created by Gourav  on 07/08/26.
//

import SwiftUI

struct LoadingScreen: View {
    var body: some View {
        ZStack {
            //bg-color
            Color(.black)
                .ignoresSafeArea()
            
            VStack{
                
                Spacer()
            
                //logo
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                
                //animation
                Spacer()
                
                VStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                    // make it big
                        .foregroundStyle(.white)
                    // visible on black (or .red for brand)
                        .symbolEffect(
                            .variableColor.iterative.hideInactiveLayers.reversing,
                            options: .repeat(.continuous)
                        )
                }
                
                 Spacer()
            }
            
        }
        
    }
}

#Preview {
    LoadingScreen()
}
