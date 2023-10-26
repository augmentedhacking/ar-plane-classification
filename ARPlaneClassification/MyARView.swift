//
//  MyARView.swift
//  ARPlaneClassification
//
//  Created by Sebastian Buys on 10/26/23.
//

import Foundation
import RealityKit
import ARKit
import Combine

class MyARView: ARView {
    var viewModel: MyARViewModel
    
    // Dictionary for storing ARPlaneAnchor(s) with AnchorEntity(s)
    var anchorEntityMap: [ARPlaneAnchor: AnchorEntity] = [:]
    
    // Custom initializer
    init(frame: CGRect, viewModel: MyARViewModel) {
        self.viewModel = viewModel
        
        // Call superclass initializer
        super.init(frame: frame)
    }
    
    // Required initializer when subclassing ARView. Since we want to use our custom initializer, we throw a fatalError to stop execution of our app.
    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    // Required initializer when subclassing ARView. Since we want to use our custom initializer, we throw a fatalError to stop execution of our app.
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // The default implementation of this method does nothing. Subclasses can override it to perform additional actions whenever the superview changes.
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.setupARSession()
    }
    
    // MARK: - AR methods
    
    // Setup ARSession configuration
    private func setupARSession() {
        let configuration = ARWorldTrackingConfiguration()
        
        // Setup configuration to detect horizontal and vertical planes
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Assign ourselves as session delegate
        self.session.delegate = self
        
        // Run session with configuration
        self.session.run(configuration)
    }
}

// MARK: - Implement ARSessionDelegate protocol
extension MyARView: ARSessionDelegate {
    // Tells the delegate that one or more anchors have been added to the session.
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Filter added anchors for plane anchors
        let planeAnchors = anchors.compactMap { $0 as? ARPlaneAnchor }
        
        planeAnchors.forEach {
            // Create a RealityKit anchor at plane anchor's position
            let anchorEntity = AnchorEntity()
            
            // Estimated size of detected plane
            let extent = $0.planeExtent
            
            // Generate a rough plane mesh based on anchor extent
            // Later we will update this plane based on more detailed geometry as ARKit learns more about our environment
            let planeMesh: MeshResource = .generatePlane(width: extent.width,
                                                         depth: extent.height)
            
            // Set color based on plane classification using our extension defined at bottom of this file
            let planeClassification = $0.classification
            
            let modelEntity = ModelEntity(mesh: planeMesh,
                                          materials: [planeClassification.debugMaterial])
            
            // Add plane model entity to anchor entity
            anchorEntity.addChild(modelEntity)
            
            // Assign AR plane anchor's transform to our anchor Entity
            anchorEntity.transform.matrix = $0.transform
            
            // Add anchor entity to our scene
            self.scene.addAnchor(anchorEntity)
            
            // Store ARKit's ARPlaneAnchor along with our associated RealityKit Anchor Entity
            self.anchorEntityMap[$0] = anchorEntity
        }
    }
    
    //Tells the delegate that the session has adjusted the properties of one or more anchors.
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Filter updated anchors for plane anchors
        let planeAnchors = anchors.compactMap { $0 as? ARPlaneAnchor }
        
        planeAnchors.forEach { planeAnchor in
            // Look for an associated AnchorEntity in our dictionary, otherwise do nothing
            guard let anchorEntity = self.anchorEntityMap[planeAnchor] else {
                return
            }
            
            // Update anchor's transform
            anchorEntity.transform.matrix = planeAnchor.transform
            
            // Look for AnchorEntity's first child that is a model entity
            // A better way to do this would use a custom entity, but this works for the tutorial
            let modelEntity = anchorEntity
                .children
                .compactMap { $0 as? ModelEntity }
                .first
            
            // Get detailed plane geometry
            var meshDescriptor = MeshDescriptor(name: "plane")
            meshDescriptor.positions = MeshBuffers.Positions(planeAnchor.geometry.vertices)
            meshDescriptor.primitives = .triangles(planeAnchor.geometry.triangleIndices.map { UInt32($0)})
            
            DispatchQueue.main.async {
                // Try creating mesh from detailed ARPlaneGeometry
                if let mesh = try? MeshResource.generate(from: [meshDescriptor]) {
                    modelEntity?.model?.mesh = mesh
                }
                
                let planeClassification = planeAnchor.classification
                modelEntity?.model?.materials = [planeClassification.debugMaterial]
            }
        }
    }
    
    // Tells the delegate that one or more anchors have been removed from the session.
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // Filter removed anchors for plane anchors
        let planeAnchors = anchors.compactMap { $0 as? ARPlaneAnchor }
        
        planeAnchors.forEach {
            // Look for an associated AnchorEntity in our dictionary, otherwise do nothing
            guard let anchorEntity = self.anchorEntityMap[$0] else {
                return
            }
            
            // Remove anchor entity from scene and dictionary
            anchorEntity.removeFromParent()
            self.anchorEntityMap.removeValue(forKey: $0)
        }
    }
}

// Extension for coloring planes by classification
extension ARPlaneAnchor.Classification {
    var debugMaterial: SimpleMaterial {
        return SimpleMaterial(color: self.debugColor.withAlphaComponent(0.9),
                              isMetallic: false)
    }
    
    var debugColor: UIColor {
        switch self {
        case .ceiling:
            return .blue
        case .door:
            return .magenta
        case .floor:
            return .red
        case .seat:
            return .green
        case .table:
            return .yellow
        case .wall:
            return .cyan
        case .window:
            return .white
        default:
            return .gray
        }
    }
}
