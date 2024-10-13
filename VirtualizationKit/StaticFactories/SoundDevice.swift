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
    
    /// This static method checks if the application has been granted permission to use the specified capture device
    /// If not determined asks for permission and throws an exception when it has not been granted
    ///
    /// - Parameters:
    ///   - type: The audio configuration type (input output ecc...)
    static private func captureDevicePermission(type: AVMediaType) async throws {

        switch AVCaptureDevice.authorizationStatus(for: type) {
            
        case .authorized:
            break
        
        case .notDetermined:
            
            guard await AVCaptureDevice.requestAccess(for: type) else {
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
