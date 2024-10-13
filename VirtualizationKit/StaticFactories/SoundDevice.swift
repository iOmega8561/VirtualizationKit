//
//  Copyright (C) Giuseppe Rocco - All Rights Reserved
//  Unauthorized copying, modification or distribution of this source code,
//  via any medium is strictly prohibited and penally persecutable
//
//  This project and its source code are PROPRIETARY AND CONFIDENTIAL
//  Written by Giuseppe Rocco <giusepperocco38@gmail.com>, May 2024
//
//  -----------------------------------------------------------------------
//
//  SoundDevice.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 17/05/24.
//

import Virtualization

import AVFoundation

/// This typealias allows for cleaner-looking code
typealias SoundDevice = VZVirtioSoundDeviceConfiguration

/// Protocol conformation of `VZVirtioSoundDeviceConfiguration` to `VZKitDeviceAttachment`
///
/// @brief
///    The `VirtHandlerMachineDevice` protocol allows for a simpler implementation of the static factory method pattern.
///    This extension contains the necessary stubs to achieve conformation and defines an appropriare `CaseIterable`
///    to be used as argument, when calling the factory method.
extension SoundDevice: VZKitDeviceAttachment {
    
    /// StreamType `CaseIterable`
    ///
    /// @brief
    ///    When calling the factory method from the outside, this `CaseIterable` becomes very useful
    ///    to provide concise information about the audio stream capabilities of the guest machine.
    enum StreamType: CaseIterable {
        case input
        case output
    }
    
    static private func captureDevicePermission(type: AVMediaType) async throws {

        switch AVCaptureDevice.authorizationStatus(for: type) {
            
        case .authorized:
            break
        
        case .notDetermined:
            
            guard await AVCaptureDevice.requestAccess(for: .audio) else {
                fallthrough
            }
                        
        default:
            throw VZKitError.captureDevicePermissionDenied
        }
    }
    
    /// This static factory method returns the appropriate audio device attachment.
    /// Audio configurations are handled the same way across different OSes, but input devices
    /// have a different setup process from output devices, and vice-versa.
    ///
    /// - Parameters:
    ///   - type: The audio configuration type (input or output)
    static func createDevice(_ type: StreamType) async throws -> SoundDevice {
        let dev = SoundDevice()
        
        switch type {
        case .output:
            
            let stream = VZVirtioSoundDeviceOutputStreamConfiguration()
            stream.sink = VZHostAudioOutputStreamSink()
            
            dev.streams.append(stream)
            
        case .input:
            
            try await Self.captureDevicePermission(type: .audio)
            
            let stream = VZVirtioSoundDeviceInputStreamConfiguration()
            stream.source = VZHostAudioInputStreamSource()
            
            dev.streams.append(stream)
            
        }
        
        return dev
    }
}
