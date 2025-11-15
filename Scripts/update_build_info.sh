#!/bin/bash

# Script to update BuildInfo.swift with current build timestamp

BUILD_INFO_FILE="${SRCROOT}/JustPlay/BuildInfo.swift"
BUILD_DATE=$(date '+%Y-%m-%d %H:%M:%S')

cat > "$BUILD_INFO_FILE" << EOF
//
//  BuildInfo.swift
//  JustPlay
//
//  This file is auto-generated during build
//

import Foundation

enum BuildInfo {
    static let buildDate = "$BUILD_DATE"
}
EOF

echo "Updated BuildInfo.swift with build date: $BUILD_DATE"
