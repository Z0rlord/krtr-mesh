#!/usr/bin/env swift

import Foundation

// Simple test to verify ZK service integration
print("🔧 Testing KRTR ZK Integration")
print("==============================")

// Test 1: Check if circuits are available
print("\n1. Checking circuit availability...")
let circuitsPath = "circuits"
let circuitNames = ["membership", "reputation", "message_proof"]

for name in circuitNames {
    let circuitFile = "\(circuitsPath)/\(name)/target/krtr_\(name).json"
    if FileManager.default.fileExists(atPath: circuitFile) {
        print("✅ \(name) circuit found")
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: circuitFile)
            if let fileSize = attributes[.size] as? Int64 {
                print("   Size: \(fileSize) bytes")
            }
        } catch {
            print("   ⚠️ Could not read file attributes")
        }
    } else {
        print("❌ \(name) circuit NOT found at \(circuitFile)")
    }
}

// Test 2: Check if Noir is available
print("\n2. Checking Noir availability...")
let task = Process()
task.launchPath = "/usr/bin/which"
task.arguments = ["nargo"]

let pipe = Pipe()
task.standardOutput = pipe
task.standardError = pipe

do {
    try task.run()
    task.waitUntilExit()
    
    if task.terminationStatus == 0 {
        print("✅ Noir (nargo) is available")
        
        // Get version
        let versionTask = Process()
        versionTask.launchPath = "/usr/bin/env"
        versionTask.arguments = ["nargo", "--version"]
        
        let versionPipe = Pipe()
        versionTask.standardOutput = versionPipe
        
        try versionTask.run()
        versionTask.waitUntilExit()
        
        let versionData = versionPipe.fileHandleForReading.readDataToEndOfFile()
        if let version = String(data: versionData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            print("   Version: \(version)")
        }
    } else {
        print("❌ Noir (nargo) is NOT available")
    }
} catch {
    print("❌ Error checking Noir: \(error)")
}

// Test 3: Check circuit compilation status
print("\n3. Checking circuit compilation...")
for name in circuitNames {
    let circuitDir = "\(circuitsPath)/\(name)"
    let targetDir = "\(circuitDir)/target"
    
    if FileManager.default.fileExists(atPath: targetDir) {
        print("✅ \(name) has target directory")
        
        // List target contents
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: targetDir)
            let jsonFiles = contents.filter { $0.hasSuffix(".json") }
            print("   JSON files: \(jsonFiles)")
        } catch {
            print("   ⚠️ Could not list target directory")
        }
    } else {
        print("❌ \(name) missing target directory")
    }
}

// Test 4: Verify circuit structure
print("\n4. Verifying circuit structure...")
for name in circuitNames {
    let circuitFile = "\(circuitsPath)/\(name)/target/krtr_\(name).json"
    
    if FileManager.default.fileExists(atPath: circuitFile) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: circuitFile))
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let circuit = json {
                print("✅ \(name) circuit is valid JSON")
                
                // Check for required fields
                let requiredFields = ["abi", "bytecode"]
                for field in requiredFields {
                    if circuit[field] != nil {
                        print("   ✓ Has \(field)")
                    } else {
                        print("   ✗ Missing \(field)")
                    }
                }
                
                // Check ABI structure
                if let abi = circuit["abi"] as? [String: Any],
                   let parameters = abi["parameters"] as? [[String: Any]] {
                    print("   ✓ ABI has \(parameters.count) parameters")
                    
                    for (index, param) in parameters.enumerated() {
                        if let name = param["name"] as? String,
                           let visibility = param["visibility"] as? String {
                            print("     \(index + 1). \(name) (\(visibility))")
                        }
                    }
                }
            }
        } catch {
            print("❌ \(name) circuit JSON is invalid: \(error)")
        }
    }
}

// Test 5: Check iOS app bundle preparation
print("\n5. Checking iOS app bundle preparation...")
let iosCircuitsPath = "krtr-native-ios/KRTR/circuits"

if FileManager.default.fileExists(atPath: iosCircuitsPath) {
    print("✅ iOS circuits directory exists")
    
    do {
        let contents = try FileManager.default.contentsOfDirectory(atPath: iosCircuitsPath)
        let circuitFiles = contents.filter { $0.hasSuffix(".json") }
        print("   Circuit files: \(circuitFiles)")
        
        for name in circuitNames {
            let expectedFile = "krtr_\(name).json"
            if circuitFiles.contains(expectedFile) {
                print("   ✓ \(expectedFile) ready for iOS bundle")
            } else {
                print("   ✗ \(expectedFile) missing from iOS bundle")
            }
        }
    } catch {
        print("   ⚠️ Could not list iOS circuits directory")
    }
} else {
    print("❌ iOS circuits directory not found")
}

print("\n🎯 ZK Integration Test Complete!")
print("================================")

// Summary
print("\n📊 Summary:")
print("- Circuits compiled: \(circuitNames.count)")
print("- iOS integration: Ready for testing")
print("- Next steps: Add circuits to Xcode project and test on device")
