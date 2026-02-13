//
//  ARViewContainer.swift
//  Aria_v1.0
//
//  Created by Brahim on 13/02/26.
//

import SwiftUI
import ARKit
import RealityKit

// MARK: - SwiftUI Wrapper

struct ARViewContainer: UIViewControllerRepresentable {
    var scanManager: LiDARScanManager
    var onObjectPlaced: (ARObjectAnchor) -> Void = { _ in }
    var onRoomRecognized: (RoomScan?) -> Void = { _ in }
    
    func makeUIViewController(context: Context) -> ARViewController {
        let controller = ARViewController(scanManager: scanManager)
        controller.onObjectPlaced = onObjectPlaced
        controller.onRoomRecognized = onRoomRecognized
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ARViewController, context: Context) {
        // Updates flow through the manager
    }
}

// MARK: - ARViewController

class ARViewController: UIViewController {
    
    var arView: ARView!
    var scanManager: LiDARScanManager
    var onObjectPlaced: (ARObjectAnchor) -> Void = { _ in }
    var onRoomRecognized: (RoomScan?) -> Void = { _ in }
    
    var meshVisualizer: MeshVisualizer?
    var selectedAnchorId: UUID? = nil
    
    init(scanManager: LiDARScanManager) {
        self.scanManager = scanManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create ARView
        let arViewFrame = view.bounds
        arView = ARView(frame: arViewFrame)
        view.addSubview(arView)
        
        // Setup gestures
        setupGestureRecognizers()
        setupDebugUI()
        
        // Create mesh visualizer
        meshVisualizer = MeshVisualizer(arView: arView)
    }
    
    // MARK: - Gesture Recognizers
    
    private func setupGestureRecognizers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        arView.addGestureRecognizer(panGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        
        // Raycast to find tap location
        if let result = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any).first {
            print("🎯 Tap at world position: \(result.worldTransform.translation)")
            
            // Try to recognize room
            let recognized = scanManager.recognizeRoom(from: scanManager.meshVertices)
            if recognized != nil {
                onRoomRecognized(recognized)
            }
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let selectedId = selectedAnchorId else { return }
        
        let location = gesture.location(in: arView)
        
        if let result = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any).first {
            // Update anchor position
            if let index = scanManager.anchors.firstIndex(where: { $0.id == selectedId }) {
                var anchor = scanManager.anchors[index]
                anchor.position = result.worldTransform.translation
                scanManager.anchors[index] = anchor
            }
        }
    }
    
    // MARK: - Debug UI
    
    private func setupDebugUI() {
        let label = UILabel()
        label.text = "Tap to place object\nDrag to move"
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
        ])
    }
    
    // MARK: - Public Methods
    
    func updateMeshVisualization() {
        guard !scanManager.meshVertices.isEmpty else { return }
        meshVisualizer?.visualizeMesh(scanManager.meshVertices)
    }
    
    func visualizePlanes() {
        for plane in scanManager.detectedPlanes {
            meshVisualizer?.visualizePlane(plane)
        }
    }
    
    func placeObject(type: ARObjectAnchor.ARObjectType, name: String) {
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        if let result = arView.raycast(from: screenCenter, allowing: .estimatedPlane, alignment: .any).first {
            scanManager.addAnchor(
                type: type,
                position: result.worldTransform.translation,
                name: name
            )
            
            meshVisualizer?.placeObject(
                position: result.worldTransform.translation,
                name: name,
                type: type
            )
        }
    }
}

// MARK: - Mesh Visualizer

class MeshVisualizer {
    let arView: ARView
    private var meshAnchor: AnchorEntity?
    private var planeVisualizers: [UUID: ModelEntity] = [:]
    private var objectVisualizers: [UUID: ModelEntity] = [:]
    
    init(arView: ARView) {
        self.arView = arView
        setupScene()
    }
    
    private func setupScene() {
        meshAnchor = AnchorEntity(plane: .horizontal)
        if let anchor = meshAnchor {
            arView.scene.anchors.append(anchor)
        }
    }
    
    func visualizeMesh(_ vertices: [SIMD3<Float>]) {
        guard !vertices.isEmpty, let meshAnchor = meshAnchor else { return }
        
        // Create simple point cloud visualization using boxes
        // Sample every Nth vertex for performance
        let sampleRate = max(1, vertices.count / 1000)
        
        for (index, vertex) in vertices.enumerated() where index % sampleRate == 0 {
            do {
                let mesh = MeshResource.generateBox(size: 0.01)
                var material = SimpleMaterial()
                material.color = .init(tint: .cyan)
                
                let pointModel = ModelEntity(mesh: mesh, materials: [material])
                var transform = Transform()
                transform.translation = vertex
                pointModel.move(to: transform, relativeTo: meshAnchor, duration: 0, timingFunction: .linear)
                
                meshAnchor.addChild(pointModel)
            } catch {
                print("❌ Error creating point entity: \(error)")
            }
        }
        
        print("✅ Mesh visualizzato: \(vertices.count) vertici (sample rate: \(sampleRate))")
    }
    
    func visualizePlane(_ plane: DetectedPlane) {
        guard let meshAnchor = meshAnchor else { return }
        
        do {
            let size = SIMD2<Float>(plane.extent.x, plane.extent.y)
            let mesh = MeshResource.generatePlane(size: size)
            var material = SimpleMaterial()
            material.color = .init(tint: .yellow)
            
            let planeModel = ModelEntity(mesh: mesh, materials: [material])
            
            var transform = Transform()
            transform.translation = plane.center
            planeModel.move(to: transform, relativeTo: meshAnchor, duration: 0, timingFunction: .linear)
            
            meshAnchor.addChild(planeModel)
            planeVisualizers[plane.id] = planeModel
            
            print("✅ Piano visualizzato a: \(plane.center)")
        } catch {
            print("❌ Error visualizing plane: \(error)")
        }
    }
    
    func placeObject(position: SIMD3<Float>, name: String, type: ARObjectAnchor.ARObjectType) {
        guard let meshAnchor = meshAnchor else { return }
        
        let tintColor: UIColor
        switch type {
        case .painting: tintColor = .red
        case .sculpture: tintColor = .green
        case .furniture: tintColor = .blue
        case .decoration: tintColor = .magenta
        case .custom: tintColor = .orange
        }
        
        do {
            let mesh = MeshResource.generateBox(size: 0.1)
            var material = SimpleMaterial()
            material.color = .init(tint: tintColor)
            
            let objectModel = ModelEntity(mesh: mesh, materials: [material])
            
            var transform = Transform()
            transform.translation = position
            objectModel.move(to: transform, relativeTo: meshAnchor, duration: 0, timingFunction: .linear)
            
            meshAnchor.addChild(objectModel)
            objectVisualizers[UUID()] = objectModel
            
            print("📍 Oggetto '\(name)' posizionato a: \(position)")
        } catch {
            print("❌ Error placing object: \(error)")
        }
    }
}
