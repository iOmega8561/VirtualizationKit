//
//  VZKitRestoreImage.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 13/11/24.
//

import Foundation

public protocol VZKitRestoreImage {
    
    associatedtype ImageType: VZKitRestoreImage
    
    associatedtype VersionType: VZKitOperatingSystemVersion
    
    var osVersion: VersionType { get }
    
    static func load(from url: URL) async throws -> ImageType
}
