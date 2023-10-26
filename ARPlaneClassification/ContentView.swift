//
//  ContentView.swift
//  ARPlaneClassification
//
//  Created by Sebastian Buys on 10/26/23.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    @State var viewModel = MyARViewModel()
    var body: some View {
        ARViewContainer(viewModel: viewModel)
            .edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    var viewModel: MyARViewModel
    
    func makeUIView(context: Context) -> ARView {
        return MyARView(frame: .zero, viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

#Preview {
    ContentView()
}
