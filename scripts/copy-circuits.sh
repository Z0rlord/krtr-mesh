#!/bin/bash

# Copy compiled Noir circuits to iOS app bundle
# This script copies the compiled .json circuit files to the iOS app resources

set -e

echo "🔧 Copying ZK circuits to iOS app bundle..."

# Define paths
CIRCUITS_DIR="circuits"
IOS_RESOURCES_DIR="krtr-native-ios/KRTR"

# Create circuits directory in iOS resources if it doesn't exist
mkdir -p "$IOS_RESOURCES_DIR/circuits"

# Copy each compiled circuit
for circuit in membership reputation message_proof; do
    source_file="$CIRCUITS_DIR/$circuit/target/krtr_$circuit.json"
    dest_file="$IOS_RESOURCES_DIR/circuits/krtr_$circuit.json"
    
    if [ -f "$source_file" ]; then
        cp "$source_file" "$dest_file"
        echo "✅ Copied $circuit circuit"
    else
        echo "❌ Circuit not found: $source_file"
        exit 1
    fi
done

echo "🎯 All circuits copied successfully!"
echo "📍 Circuits available at: $IOS_RESOURCES_DIR/circuits/"
