//
//  OperatingSystem.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 16/05/24.
//

import SwiftUI

import Virtualization

import UniformTypeIdentifiers

/// This enumeration has been created to define the possible operating systems that can be associated to a virtual machine.
/// Since Apple Virtualization Framework officially supports only Linux and macOS, only these two are included.
public enum OperatingSystem: VZKitOperatingSystem {
    
    /// Conformation to `CaseIterable`
    public static let allCases: [Self] = [
        .linux,
        .macos()
    ]
    
    case linux
    case macos(_ major: Int = 12, _ minor: Int = 4)
    
    /// Static factory method to create an `OperatingSytem` object, using information retrieved by
    /// the provided macOS restore image (if present). It allows to manipulate the enum cases to have them store things like OS version.
    ///
    /// - Parameters:
    ///   - expected: The OS type to be expected in return, will probably be blank (no version)
    ///   - url: The URL of the installer image provided by the caller. If expected in not .macos this parameter has no effect.
    public static func createOS(expected: Self, _ url: URL) async throws -> OperatingSystem {
        
        guard expected != .linux else { return .init() }
        
        let version: (Int, Int) = try await withCheckedThrowingContinuation { continuation in
            VZMacOSRestoreImage.load(from: url) { result in
                switch result {
                    
                case .failure(let error):
                    continuation.resume(throwing: error)
                    
                case .success(let restoreImage):
                    
                    let major = restoreImage.operatingSystemVersion.majorVersion
                    let minor = restoreImage.operatingSystemVersion.minorVersion
                    
                    continuation.resume(returning: (major, minor))
                }
            }
        }
        
        return .init(version)
    }
    
    public var image: Image {
        switch self {
        case .linux:
            return Image("tux", bundle: VirtualizationKit.bundle)
        case .macos:
            return Image(systemName: "apple.logo")
        }
    }
    
    public var label: Text {
        switch self {
        case .linux:
            return Text(verbatim: "Linux")
        case .macos:
            return Text(verbatim: "macOS")
        }
    }
    
    public var fileType: UTType {
        switch self {
        case .linux:
            return .diskImage
        case .macos:
            return UTType(filenameExtension: "ipsw")!
        }
    }
    
    /// This private `init()` will instanciate the right case, depending on if version is `nil` or not
    private init(_ version: (Int, Int)? = nil) {
        
        if let version {
            self = .macos(version.0, version.1)
        } else {
            self = .linux
        }
    }
}
