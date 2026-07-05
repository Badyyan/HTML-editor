// swift-tools-version:5.9
//
//  Package.swift
//  HTML Editor — a native macOS HTML editor built with SwiftUI + AppKit + WebKit.
//
//  Open this file directly in Xcode (File ▸ Open…) and press Run,
//  or generate a full .xcodeproj with XcodeGen using project.yml.
//
import PackageDescription

let package = Package(
    name: "HTMLEditor",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "HTMLEditor",
            path: "Sources/HTMLEditor"
        ),
        .testTarget(
            name: "HTMLEditorTests",
            dependencies: ["HTMLEditor"],
            path: "Tests/HTMLEditorTests"
        )
    ]
)
