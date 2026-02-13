//
//  LiDAR.swift
//  Aria_v1.0
//
//  Created by Brahim on 13/02/26.
//

import Foundation
import ARKit
import simd

// MARK: - Room Data Model

struct RoomScan: Codable, Identifiable {
    let id: UUID
    var name: String
    var timestamp: Date
    var meshData: Data  // Encoded ModelEntity mesh
    var anchorsData: [ARObjectAnchor]
    var roomSignature: String  // Hash per room recognition
    
    init(id: UUID = UUID(), name: String, meshData: Data, anchorsData: [ARObjectAnchor]) {
        self.id = id
        self.name = name
        self.timestamp = Date()
        self.meshData = meshData
        self.anchorsData = anchorsData
        self.roomSignature = Self.generateSignature(from: meshData)
    }
    
    static func generateSignature(from meshData: Data) -> String {
        let hash = meshData.withUnsafeBytes { buffer in
            // Simple hash calculation
            var result: UInt64 = 5381
            for byte in buffer {
                result = ((result << 5) &+ result) &+ UInt64(byte)
            }
            return result
        }
        return String(format: "%llx", hash)
    }
}

// MARK: - AR Object Anchor (Persistent)

struct ARObjectAnchor: Codable, Identifiable {
    let id: UUID
    var type: ARObjectType
    var position: SIMD3<Float>  // World position
    var rotation: Rotation4  // Quaternion
    var scale: SIMD3<Float>
    var modelPath: String  // Path to 3D model
    var name: String
    var createdAt: Date
    
    enum ARObjectType: String, Codable {
        case painting
        case sculpture
        case furniture
        case decoration
        case custom
    }
    
    init(id: UUID = UUID(),
         type: ARObjectType,
         position: SIMD3<Float>,
         rotation: Rotation4 = Rotation4(),
         scale: SIMD3<Float> = [1, 1, 1],
         modelPath: String = "",
         name: String = "Object") {
        self.id = id
        self.type = type
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.modelPath = modelPath
        self.name = name
        self.createdAt = Date()
    }
}

// MARK: - Quaternion Codable Wrapper

struct Rotation4: Codable, Equatable {
    var x: Float
    var y: Float
    var z: Float
    var w: Float
    
    init(x: Float = 0, y: Float = 0, z: Float = 0, w: Float = 1) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
    
    init(simdQuat: simd_quatf) {
        self.x = simdQuat.vector.x
        self.y = simdQuat.vector.y
        self.z = simdQuat.vector.z
        self.w = simdQuat.vector.w
    }
    
    var simdQuat: simd_quatf {
        simd_quatf(ix: x, iy: y, iz: z, r: w)
    }
}

// MARK: - LiDAR Depth Frame

struct LiDARFrame {
    let depthMap: CVPixelBuffer
    let timestamp: TimeInterval
    let intrinsics: matrix_float3x3
    let position: simd_float3
    let orientation: simd_quatf
}
