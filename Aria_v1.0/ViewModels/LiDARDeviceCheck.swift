//
//  LiDARDeviceCheck.swift
//  Aria_v1.0
//
//  Created by Brahim on 13/02/26.
//

import Foundation
import ARKit
import AVFoundation

final class LiDARDeviceCheck {
    
    // MARK: - Device Capabilities
    
    static var isLiDARSupported: Bool {
        guard ARWorldTrackingConfiguration.isSupported else { return false }
        
        // Check depth data support (LiDAR)
        return ARWorldTrackingConfiguration
            .supportsFrameSemantics(.personSegmentationWithDepth)
    }
    
    static var isFaceTrackingSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }
    
    static var cameraAuthorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    // MARK: - Request Permissions
    
    static func requestCameraPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        return granted
    }
    
    // MARK: - Validation
    
    static func validateARSupport() -> ARValidationResult {
        var result = ARValidationResult()
        
        // Check device
        if !ARWorldTrackingConfiguration.isSupported {
            result.errors.append("ARKit non supportato su questo dispositivo")
            return result
        }
        
        // Check LiDAR
        if !isLiDARSupported {
            result.warnings.append("⚠️ LiDAR non disponibile. La scansione avrà qualità reduced.")
            result.canContinue = true
        } else {
            result.lidarAvailable = true
        }
        
        // Check camera permission
        switch cameraAuthorizationStatus {
        case .authorized:
            result.cameraPermissionGranted = true
        case .denied:
            result.errors.append("❌ Permesso camera negato. Vai in Impostazioni > Aria > Camera")
        case .restricted:
            result.errors.append("❌ Uso della camera è limitato on questo dispositivo")
        case .notDetermined:
            result.cameraPermissionGranted = false
        @unknown default:
            result.warnings.append("⚠️ Stato permesso camera sconosciuto")
        }
        
        return result
    }
    
    // MARK: - Device Info
    
    static func getDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        
        return DeviceInfo(
            model: device.model,
            systemVersion: device.systemVersion,
            hasLiDAR: isLiDARSupported,
            hasFaceTracking: isFaceTrackingSupported,
            cameraAuthorized: cameraAuthorizationStatus == .authorized
        )
    }
}

// MARK: - Result Models

struct ARValidationResult {
    var errors: [String] = []
    var warnings: [String] = []
    var lidarAvailable: Bool = false
    var cameraPermissionGranted: Bool = false
    var canContinue: Bool = false
    
    var isValid: Bool {
        errors.isEmpty && cameraPermissionGranted
    }
}

struct DeviceInfo {
    let model: String
    let systemVersion: String
    let hasLiDAR: Bool
    let hasFaceTracking: Bool
    let cameraAuthorized: Bool
}
