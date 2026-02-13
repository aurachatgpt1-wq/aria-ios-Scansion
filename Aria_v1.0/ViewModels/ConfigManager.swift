//
//  ConfigManager.swift
//  Aria_v1.0
//
//  Created by Brahim on 13/02/26.
//

import Foundation

struct ConfigManager {
    
    /// OpenAI API Key - Load from environment or Config.plist
    static var openAIAPIKey: String {
        // Try to load from environment first
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            return envKey
        }
        
        // Fallback to Info.plist
        if let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String {
            return key
        }
        
        // This will cause a runtime error if not configured
        fatalError("❌ OPENAI_API_KEY not configured. Please set it in Info.plist or environment variables.")
    }
    
    /// OpenAI Assistant ID - Load from environment or Config.plist
    static var openAIAssistantId: String {
        // Try to load from environment first
        if let envId = ProcessInfo.processInfo.environment["OPENAI_ASSISTANT_ID"] {
            return envId
        }
        
        // Fallback to Info.plist
        if let id = Bundle.main.infoDictionary?["OPENAI_ASSISTANT_ID"] as? String {
            return id
        }
        
        // This will cause a runtime error if not configured
        fatalError("❌ OPENAI_ASSISTANT_ID not configured. Please set it in Info.plist or environment variables.")
    }
}

/*
 SETUP INSTRUCTIONS:
 
 There are two ways to configure API keys securely:
 
 ## Option 1: Info.plist (Development)
 1. Open Aria-v1-0-Info.plist
 2. Add two new keys:
    - Key: OPENAI_API_KEY
      Value: Your API key (sk-proj-...)
    - Key: OPENAI_ASSISTANT_ID
      Value: Your Assistant ID (asst_...)
 3. Build and run
 
 ## Option 2: Environment Variables (Recommended for CI/CD)
 1. Set environment variables before building:
    export OPENAI_API_KEY="your_key_here"
    export OPENAI_ASSISTANT_ID="your_id_here"
 2. Build and run
 
 ## Option 3: Build Settings (Production)
 1. In Xcode, go to Build Settings
 2. Search for "User-Defined"
 3. Add OPENAI_API_KEY and OPENAI_ASSISTANT_ID
 4. Reference in Run Script or manually set
 
 ⚠️ NEVER commit API keys to git!
 ⚠️ Always use .gitignore for sensitive files
 */
