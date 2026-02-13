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

class ARViewController: UIViewController, ARViewDelegate {
    
    var arView: ARView!
    var scanManager: LiDARScanManager
    var onObjectPlaced: (ARObjectAnchor) -> Void = { _ in }
    var onRoomRecognized: (RoomScan?) -> Void = { _ in }
    
    var meshVisualizer: MeshVisualizer?
    var tapGestureRecognizer: UITapGestureRecognizer?
    var panGestureRecognizer: UIPanGestureRecognizer?
    
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
        
        let arView = ARView(frame: view.bounds)
        self.arView = arView
        view.addSubview(arView)
        
        setupGestureRecognizers()
        setupDebugUI()
        
        meshVisualizer = MeshVisualizer(arView: arView)
    }
    
    // MARK: - Gesture Recognizers
    
    private func setupGestureRecognizers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        self.tapGestureRecognizer = tapGesture
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        arView.addGestureRecognizer(panGesture)
        self.panGestureRecognizer = panGesture
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        
        // Raycasting per rilevare click su anchorare
        if let result = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any).first {
            
            // Slot per mostrare UI di posizionamento
            print("🎯 Posizionamento richiesto a: \(result.worldTransform.translation)")
        }
        
        // Riconosci stanza se non ancora fatto
        let recognized = scanManager.recognizeRoom(from: scanManager.meshVertices)
        onRoomRecognized(recognized)
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
    
    // MARK: - Mesh Visualization
    
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
        // Add object at center screen
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        if let result = arView.raycast(from: screenCenter, allowing: .estimatedPlane, alignment: .any).first {
            scanManager.addAnchor(
                type: type,
                position: result.worldTransform.translation,
                name: name
            )
            
            // Create visual representation
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
        
        // Create point cloud mesh
        var meshDescriptor = MeshDescriptor()
        meshDescriptor.positions = MeshDescriptor.Positions(vertices)
        
        // Create indices
        let indices = (0..<UInt32(vertices.count)).map { UInt32($0) }
        meshDescriptor.primitives = [
            .triangle(indices.map { NSNumber(value: $0) })
        ]
        
        do {
            let mesh = try Mesh(descriptor: meshDescriptor)
            var material = Material()
            material.color = .init(tint: .cyan.withAlphaComponent(0.5))
            
            let meshModel = ModelEntity(mesh: mesh, materials: [material])
            meshAnchor.addChild(meshModel)
            
            print("✅ Mesh visualizzato: \(vertices.count) vertici")
        } catch {
            print("❌ Errore mesh: \(error)")
        }
    }
    
    func visualizePlane(_ plane: DetectedPlane) {
        guard let meshAnchor = meshAnchor else { return }
        
        let extent = plane.extent
        let mesh = MeshResource.generatePlane(size: extent)
        var material = Material()
        material.color = .init(tint: .yellow.withAlphaComponent(0.3))
        
        let planeModel = ModelEntity(mesh: mesh, materials: [material])
        planeModel.move(
            to: Transform(translation: plane.center),
            relativeTo: meshAnchor,
            duration: 0,
            timingFunction: .linear
        )
        
        meshAnchor.addChild(planeModel)
        planeVisualizers[plane.id] = planeModel
    }
    
    func placeObject(position: SIMD3<Float>, name: String, type: ARObjectAnchor.ARObjectType) {
        guard let meshAnchor = meshAnchor else { return }
        
        let color: UIColor
        switch type {
        case .painting: color = .red
        case .sculpture: color = .green
        case .furniture: color = .blue
        case .decoration: color = .magenta
        case .custom: color = .orange
        }
        
        let mesh = MeshResource.generateBox(size: 0.1)
        var material = Material()
        material.color = .init(tint: color)
        
        let objectModel = ModelEntity(mesh: mesh, materials: [material])
        objectModel.position = position
        
        meshAnchor.addChild(objectModel)
        
        print("📍 Oggetto posizionato: \(name) a \(position)")
    }
}
