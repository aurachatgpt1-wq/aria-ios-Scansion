//
//  RoomStorageManager.swift
//  Aria_v1.0
//
//  Created by Brahim on 13/02/26.
//

import Foundation

final class RoomStorageManager {
    static let shared = RoomStorageManager()
    
    private let fileManager = FileManager.default
    private lazy var scansDirectory: URL = {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let scans = appSupport.appendingPathComponent("LiDARScans")
        try? fileManager.createDirectory(at: scans, withIntermediateDirectories: true)
        return scans
    }()
    
    private lazy var anchorsDirectory: URL = {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let anchors = appSupport.appendingPathComponent("ARAnchors")
        try? fileManager.createDirectory(at: anchors, withIntermediateDirectories: true)
        return anchors
    }()
    
    // MARK: - Save Operations
    
    func saveRoomScan(_ scan: RoomScan) throws {
        let fileURL = scansDirectory.appendingPathComponent("\(scan.id).room")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let encoded = try encoder.encode(scan)
        try encoded.write(to: fileURL)
        
        print("✅ Scan salvato: \(scan.name)")
    }
    
    func saveAnchors(_ anchors: [ARObjectAnchor], roomId: UUID) throws {
        let fileURL = anchorsDirectory.appendingPathComponent("\(roomId).anchors")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let encoded = try encoder.encode(anchors)
        try encoded.write(to: fileURL)
        
        print("✅ Anchors salvati per stanza: \(roomId)")
    }
    
    // MARK: - Load Operations
    
    func loadAllRooms() throws -> [RoomScan] {
        let files = try fileManager.contentsOfDirectory(at: scansDirectory, includingPropertiesForKeys: nil)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var rooms: [RoomScan] = []
        
        for file in files where file.pathExtension == "room" {
            if let data = try? Data(contentsOf: file),
               let room = try? decoder.decode(RoomScan.self, from: data) {
                rooms.append(room)
            }
        }
        
        return rooms.sorted { $0.timestamp > $1.timestamp }
    }
    
    func loadRoomScan(id: UUID) throws -> RoomScan? {
        let fileURL = scansDirectory.appendingPathComponent("\(id).room")
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(RoomScan.self, from: data)
    }
    
    func loadAnchors(roomId: UUID) throws -> [ARObjectAnchor] {
        let fileURL = anchorsDirectory.appendingPathComponent("\(roomId).anchors")
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([ARObjectAnchor].self, from: data)
    }
    
    // MARK: - Delete Operations
    
    func deleteRoom(id: UUID) throws {
        let roomFile = scansDirectory.appendingPathComponent("\(id).room")
        let anchorsFile = anchorsDirectory.appendingPathComponent("\(id).anchors")
        
        try? fileManager.removeItem(at: roomFile)
        try? fileManager.removeItem(at: anchorsFile)
        
        print("🗑️  Stanza eliminata: \(id)")
    }
    
    // MARK: - Export/Import
    
    func exportRoom(id: UUID, to url: URL) throws {
        guard let room = try loadRoomScan(id: id) else {
            throw NSError(domain: "RoomStorageManager", code: 404, userInfo: nil)
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let encoded = try encoder.encode(room)
        try encoded.write(to: url)
    }
    
    func importRoom(from url: URL) throws -> RoomScan {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let data = try Data(contentsOf: url)
        let room = try decoder.decode(RoomScan.self, from: data)
        
        try saveRoomScan(room)
        return room
    }
}
