//
//  LiDARScanManager.swift
//  Aria_v1.0
//
//  Created by Brahim on 13/02/26.
//

import Foundation
import ARKit
import RealityKit
import AVFoundation
import MetalKit

@Observable @MainActor
final class LiDARScanManager: NSObject {
    
    // MARK: - State
    var isScanning = false
    var scanProgress: Float = 0
    var currentRoomName = ""
    var meshVertices: [SIMD3<Float>] = []
    var detectedPlanes: [DetectedPlane] = []
    var anchors: [ARObjectAnchor] = []
    var scannedRooms: [RoomScan] = []
    
    // MARK: - ARKit
    private var arSession: ARSession?
    private var configuration: ARWorldTrackingConfiguration?
    private var depthFrames: [LiDARFrame] = []
    
    // MARK: - Metal
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    
    // MARK: - Detection
    var detectedSurfaces: [(plane: ARPlaneAnchor, confidence: Float)] = []
    
    override init() {
        super.init()
        setupARSession()
        loadSavedRooms()
    }
    
    // MARK: - ARSession Setup
    
    private func setupARSession() {
        let session = ARSession()
        self.arSession = session
        
        configuration = ARWorldTrackingConfiguration()
        
        // Enable LiDAR if available
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration?.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        // Enable plane detection
        configuration?.planeDetection = [.horizontal, .vertical]
        
        // Frame semantics per depth
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.rawFeaturePoints) {
            configuration?.frameSemantics.insert(.rawFeaturePoints)
        }
        
        if let config = configuration {
            session.delegate = self
            session.run(config)
        }
    }
    
    // MARK: - Scanning
    
    func startScanning(roomName: String) {
        isScanning = true
        currentRoomName = roomName
        meshVertices.removeAll()
        detectedPlanes.removeAll()
        depthFrames.removeAll()
        detectedSurfaces.removeAll()
        scanProgress = 0
    }
    
    func stopScanning() async {
        isScanning = false
        
        // Process mesh dall'accumulato depth frames
        await processMeshFromDepthFrames()
    }
    
    // MARK: - Depth Processing
    
    private func processMeshFromDepthFrames() async {
        guard !depthFrames.isEmpty else { return }
        
        var allVertices: [SIMD3<Float>] = []
        
        for frame in depthFrames {
            let vertices = extractVerticesFromDepth(
                depthMap: frame.depthMap,
                intrinsics: frame.intrinsics,
                cameraTransform: float4x4(translation: frame.position, rotation: frame.orientation)
            )
            allVertices.append(contentsOf: vertices)
        }
        
        // Filter e mesh decimation
        let decimatedVertices = performMeshDecimation(vertices: allVertices)
        self.meshVertices = decimatedVertices
        
        scanProgress = 1.0
        print("✅ Mesh elaborato: \(decimatedVertices.count) vertici")
    }
    
    private func extractVerticesFromDepth(
        depthMap: CVPixelBuffer,
        intrinsics: matrix_float3x3,
        cameraTransform: float4x4
    ) -> [SIMD3<Float>] {
        var vertices: [SIMD3<Float>] = []
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return [] }
        
        let buffer = baseAddress.assumingMemoryBound(to: Float16.self)
        
        // Sample every Nth pixel per performance
        let sampleRate = 4
        
        for y in stride(from: 0, to: height, by: sampleRate) {
            for x in stride(from: 0, to: width, by: sampleRate) {
                let depth = Float(buffer[y * width + x])
                
                guard depth > 0.1 && depth < 10.0 else { continue }
                
                // Back-project depth to 3D
                let xy = SIMD2<Float>(Float(x), Float(y))
                let point3D = backprojectDepth(xy, depth, intrinsics)
                
                // Transform to world space
                let worldPoint = transformPoint(point3D, by: cameraTransform)
                vertices.append(worldPoint)
            }
        }
        
        return vertices
    }
    
    private func backprojectDepth(
        _ xy: SIMD2<Float>,
        _ depth: Float,
        _ intrinsics: matrix_float3x3
    ) -> SIMD3<Float> {
        let fx = intrinsics.columns.0.x
        let fy = intrinsics.columns.1.y
        let cx = intrinsics.columns.2.x
        let cy = intrinsics.columns.2.y
        
        let x = (xy.x - cx) * depth / fx
        let y = (xy.y - cy) * depth / fy
        let z = depth
        
        return SIMD3<Float>(x, y, z)
    }
    
    private func transformPoint(_ point: SIMD3<Float>, by transform: float4x4) -> SIMD3<Float> {
        let homogeneous = SIMD4<Float>(point.x, point.y, point.z, 1)
        let transformed = transform * homogeneous
        return SIMD3<Float>(transformed.x, transformed.y, transformed.z) / transformed.w
    }
    
    private func performMeshDecimation(vertices: [SIMD3<Float>], targetCount: Int = 50000) -> [SIMD3<Float>] {
        guard vertices.count > targetCount else { return vertices }
        
        // Simple grid-based decimation
        let step = vertices.count / targetCount
        return stride(from: 0, to: vertices.count, by: max(1, step)).map { vertices[$0] }
    }
    
    // MARK: - Plane Detection
    
    func updateDetectedPlanes() {
        guard let frame = arSession?.currentFrame else { return }
        
        var planes: [DetectedPlane] = []
        
        for anchor in frame.anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                let plane = DetectedPlane(
                    id: UUID(),
                    extent: planeAnchor.extent,
                    center: planeAnchor.center,
                    alignment: planeAnchor.alignment,
                    transform: planeAnchor.transform
                )
                planes.append(plane)
            }
        }
        
        self.detectedPlanes = planes
    }
    
    // MARK: - Anchor Management
    
    func addAnchor(
        type: ARObjectAnchor.ARObjectType,
        position: SIMD3<Float>,
        name: String,
        modelPath: String = ""
    ) {
        let anchor = ARObjectAnchor(
            type: type,
            position: position,
            modelPath: modelPath,
            name: name
        )
        anchors.append(anchor)
    }
    
    func removeAnchor(id: UUID) {
        anchors.removeAll { $0.id == id }
    }
    
    // MARK: - Persistence
    
    func saveScan() async {
        let roomScan = RoomScan(
            name: currentRoomName,
            meshData: encodeMesh(),
            anchorsData: anchors
        )
        
        scannedRooms.append(roomScan)
        await persistToStorage(roomScan)
    }
    
    private func encodeMesh() -> Data {
        let encoder = JSONEncoder()
        let meshData = meshVertices.map { ["x": $0.x, "y": $0.y, "z": $0.z] }
        
        if let encoded = try? encoder.encode(meshData) {
            return encoded
        }
        return Data()
    }
    
    private func persistToStorage(_ scan: RoomScan) async {
        let fileManager = FileManager.default
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let scansDir = appSupportDir.appendingPathComponent("LiDARScans")
        
        try? fileManager.createDirectory(at: scansDir, withIntermediateDirectories: true)
        
        let scanFile = scansDir.appendingPathComponent("\(scan.id).json")
        let encoder = JSONEncoder()
        
        if let encoded = try? encoder.encode(scan) {
            try? encoded.write(to: scanFile)
            print("✅ Scan salvato: \(scanFile.lastPathComponent)")
        }
    }
    
    private func loadSavedRooms() {
        let fileManager = FileManager.default
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let scansDir = appSupportDir.appendingPathComponent("LiDARScans")
        
        guard fileManager.fileExists(atPath: scansDir.path) else { return }
        
        if let files = try? fileManager.contentsOfDirectory(at: scansDir, includingPropertiesForKeys: nil) {
            let decoder = JSONDecoder()
            
            for file in files where file.pathExtension == "json" {
                if let data = try? Data(contentsOf: file),
                   let scan = try? decoder.decode(RoomScan.self, from: data) {
                    scannedRooms.append(scan)
                }
            }
        }
    }
    
    // MARK: - Room Recognition
    
    func recognizeRoom(from currentMesh: [SIMD3<Float>]) -> RoomScan? {
        let currentSignature = RoomScan.generateSignature(
            from: encodeMesh()
        )
        
        // Find best match
        let match = scannedRooms.min { scan1, scan2 in
            let similarity1 = calculateMeshSimilarity(scan1.roomSignature, currentSignature)
            let similarity2 = calculateMeshSimilarity(scan2.roomSignature, currentSignature)
            return similarity1 > similarity2
        }
        
        if let match = match {
            let threshold: Float = 0.85
            let similarity = calculateMeshSimilarity(match.roomSignature, currentSignature)
            
            if similarity > threshold {
                print("🎯 Stanza riconosciuta: \(match.name) (similarity: \(similarity))")
                return match
            }
        }
        
        return nil
    }
    
    private func calculateMeshSimilarity(_ sig1: String, _ sig2: String) -> Float {
        // Simple string similarity
        let common = zip(sig1, sig2).filter { $0 == $1 }.count
        let total = max(sig1.count, sig2.count)
        return Float(common) / Float(total)
    }
}

// MARK: - ARSessionDelegate

extension LiDARScanManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isScanning else { return }
        
        // Collect depth frames
        if let depthData = frame.capturedDepthData {
            let lidarFrame = LiDARFrame(
                depthMap: depthData.depthDataMap,
                timestamp: frame.timestamp,
                intrinsics: depthData.intrinsics,
                position: frame.camera.transform.translation,
                orientation: frame.camera.transform.rotation
            )
            depthFrames.append(lidarFrame)
        }
        
        // Update plane detection
        updateDetectedPlanes()
        
        // Update progress
        scanProgress = min(1.0, Float(depthFrames.count) / 300.0)
    }
}

// MARK: - Helper Structures

struct DetectedPlane: Identifiable {
    let id: UUID
    let extent: SIMD2<Float>
    let center: SIMD3<Float>
    let alignment: ARPlaneAnchor.Alignment
    let transform: simd_float4x4
}

// MARK: - Transform Helpers

extension simd_float4x4 {
    init(translation: SIMD3<Float>, rotation: simd_quatf) {
        let rotationMatrix = float3x3(rotation)
        self.init(
            SIMD4<Float>(rotationMatrix[0], 0),
            SIMD4<Float>(rotationMatrix[1], 0),
            SIMD4<Float>(rotationMatrix[2], 0),
            SIMD4<Float>(translation, 1)
        )
    }
    
    var translation: SIMD3<Float> {
        SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
    
    var rotation: simd_quatf {
        let rotationMatrix = float3x3(
            columns.0.xyz,
            columns.1.xyz,
            columns.2.xyz
        )
        return simd_quatf(rotationMatrix)
    }
}

extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        SIMD3<Float>(x, y, z)
    }
}
