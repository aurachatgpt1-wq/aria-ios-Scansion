//
//  LiDARScannerView.swift
//  Aria_v1.0
//
//  Created by Brahim on 13/02/26.
//

import SwiftUI
import ARKit

struct LiDARScannerView: View {
    @State private var scanManager = LiDARScanManager()
    @State private var showObjectPlacer = false
    @State private var selectedRoomScan: RoomScan? = nil
    @State private var roomName = "My Room"
    @State private var isProcessing = false
    @State private var validationResult: ARValidationResult = ARValidationResult()
    @State private var showValidationAlert = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Validation Alert
            if showValidationAlert && !validationResult.isValid {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        if !validationResult.errors.isEmpty {
                            Text("❌ Errori:")
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                            
                            ForEach(validationResult.errors, id: \.self) { error in
                                Text("• " + error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        if !validationResult.warnings.isEmpty {
                            Text("⚠️ Avvisi:")
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                                .padding(.top, 8)
                            
                            ForEach(validationResult.warnings, id: \.self) { warning in
                                Text("• " + warning)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    if !validationResult.isValid {
                        Button(action: { showValidationAlert = false }) {
                            Text("OK")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
            }
            
            // MARK: - AR View
            ARViewContainer(
                scanManager: scanManager,
                onObjectPlaced: { anchor in
                    scanManager.anchors.append(anchor)
                },
                onRoomRecognized: { room in
                    selectedRoomScan = room
                }
            )
            .ignoresSafeArea()
            
            // MARK: - Top Controls
            VStack {
                HStack {
                    Text(scanManager.isScanning ? "🔴 Scanning..." : "Ready")
                        .font(.headline)
                        .foregroundStyle(scanManager.isScanning ? .red : .green)
                    
                    Spacer()
                    
                    Button(action: { showObjectPlacer.toggle() }) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.blue.opacity(0.7))
                            .clipShape(Circle())
                    }
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
                
                Spacer()
            }
            
            // MARK: - Bottom Controls
            VStack(spacing: 12) {
                // Progress bar
                if scanManager.isScanning {
                    ProgressView(value: Double(scanManager.scanProgress))
                        .tint(.green)
                        .padding()
                }
                
                // Room Recognition Status
                if let room = selectedRoomScan {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Stanza riconosciuta: \(room.name)")
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }
                
                // Control buttons
                HStack(spacing: 12) {
                    if !scanManager.isScanning {
                        Button(action: startScanning) {
                            Label("Start Scan", systemImage: "scan")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    } else {
                        Button(action: stopScanning) {
                            Label("Stop Scan", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    
                    if !scanManager.isScanning && !scanManager.meshVertices.isEmpty {
                        Button(action: saveScan) {
                            Label("Save", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            }
            
            // MARK: - Object Placer Sheet
            if showObjectPlacer {
                ObjectPlacerSheet(
                    scanManager: scanManager,
                    isPresented: $showObjectPlacer
                )
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            validationResult = LiDARDeviceCheck.validateARSupport()
            showValidationAlert = !validationResult.isValid
            
            if validationResult.cameraPermissionGranted == false {
                Task {
                    let granted = await LiDARDeviceCheck.requestCameraPermission()
                    if !granted {
                        validationResult.errors.append("Camera permission is required")
                        showValidationAlert = true
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startScanning() {
        if roomName.isEmpty {
            roomName = "My Room"
        }
        scanManager.startScanning(roomName: roomName)
    }
    
    private func stopScanning() {
        Task {
            await scanManager.stopScanning()
        }
    }
    
    private func saveScan() {
        Task {
            isProcessing = true
            await scanManager.saveScan()
            isProcessing = false
        }
    }
}

// MARK: - Object Placer Sheet

struct ObjectPlacerSheet: View {
    var scanManager: LiDARScanManager
    @Binding var isPresented: Bool
    
    @State private var selectedType: ARObjectAnchor.ARObjectType = .painting
    @State private var objectName = "My Object"
    @State private var modelPath = ""
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Place Object")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.gray)
                }
            }
            .padding()
            
            Divider()
            
            // Type selection
            Picker("Object Type", selection: $selectedType) {
                ForEach([
                    ARObjectAnchor.ARObjectType.painting,
                    .sculpture,
                    .furniture,
                    .decoration,
                    .custom
                ], id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Name input
            TextField("Object Name", text: $objectName)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            // Model path input
            TextField("Model Path (optional)", text: $modelPath)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            Spacer()
            
            // Place button
            Button(action: placeObject) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Place at Center")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
    }
    
    private func placeObject() {
        scanManager.addAnchor(
            type: selectedType,
            position: [0, -0.5, -0.5],  // Center of screen
            name: objectName,
            modelPath: modelPath
        )
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    LiDARScannerView()
}
