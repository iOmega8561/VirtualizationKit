//
//  MacOSInstaller.swift
//  VirtualizationKit
//
//  Created by Giuseppe Rocco on 09/01/25.
//

@preconcurrency import Virtualization

/// A specialized macOS installer for virtual machines tailored for default implementations in `VirtualizationKit`.
///
/// The `MacOSInstaller` class extends `VZMacOSInstaller` and conforms to `VZKitStatefulInstaller`,
/// offering functionality to install macOS on virtual machines. It provides additional
/// capabilities for handling macOS restore images and integrates with `ObservableCoordinator`
/// to track installation progress and machine state.
///
/// ## Features
/// - Tracks and reports installation progress using `ObservableCoordinator`.
/// - Validates macOS restore images for compatibility with the target template.
/// - Provides both synchronous and asynchronous initialization for flexible use cases.
/// - Conforms to Swift's concurrency model with support for `async/await`.
///
/// ## Generic Parameter
/// - `Template`: A type conforming to `VZKitTemplate`, representing the template configuration for the virtual machine.
///
/// ## Inheritance
/// This class inherits from `VZMacOSInstaller` and conforms to `VZKitStatefulInstaller`.
///
/// ## Usage
/// ```swift
/// let installer = try MacOSInstaller(virtualMachine: myVirtualMachine)
/// try await installer.restoreFromDiskImage()
/// ```
///
/// ## Concurrency
/// The `MacOSInstaller` supports asynchronous operations for installation and validation of restore images.
/// Ensure that the calling context supports Swift concurrency.
///
/// ## Errors
/// - `VZKitError.missingMacImage`: Thrown if the required macOS restore image is missing.
/// - `VZKitError.macUnsupportedImage`: Thrown if the restore image is incompatible with macOS.
/// - `VZKitError.wrongMacImageVersion`: Thrown if the macOS version in the restore image does not match the template.
///
/// - Note: This class is open for subclassing and can be extended to include additional functionality.
///
/// ## Example
/// ```swift
/// do {
///     let installer = try MacOSInstaller(virtualMachine: myVirtualMachine)
///     try await installer.restoreFromDiskImage()
///     print("Installation completed successfully.")
/// } catch {
///     print("Installation failed with error: \(error)")
/// }
/// ```
struct MacOSInstaller<Template: VZKitTemplate>: VZKitStatefulInstaller {

    // MARK: - Properties
    
    /// The state coordinator for tracking progress and state updates during installation.
    ///
    /// The `vzKitStateCoordinator` integrates with `ObservableCoordinator` to monitor installation
    /// progress and update observers as necessary.
    public let vzKitStateCoordinator: ObservableCoordinator

    /// A convenient NSProgress object that will be effective to observe the installation progress,
    /// although it's generally recommended to use vzKitStateCoordinator.
    public var legacyProgress: Progress { vzMacOSInstaller.progress }
    
    /// The Virtualization.framework Installer object that will effectively handle the installation process
    /// on the back end. This struct is very effectively a wrapper around this.
    private let vzMacOSInstaller: VZMacOSInstaller
    
    // MARK: - Methods

    /// Restores the macOS installation from a disk image asynchronously.
    ///
    /// This method registers the installer’s progress updates with the state coordinator and
    /// performs the macOS installation process using `async/await`.
    ///
    /// - Throws: An error if the installation process encounters an issue.
    /// - Note: Every operation that is dispatched on a `VZVirtualMachine` **is required**
    /// to be executed on the same thread on which the `VZVirtualMachine` was first created. Since
    /// the default implementation that this frameworks provides uses `VZKitActor`, this method is pinned to it.
    @VZKitActor public func restoreFromDiskImage() async throws {
        
        if await vzKitStateCoordinator.currentState != .restoring {
            await vzKitStateCoordinator.update(with: .restoring)
        }
        
        await vzKitStateCoordinator.registerPublisher(
            vzMacOSInstaller.progress.publisher(for: \.fractionCompleted)
        )
        
        try await vzMacOSInstaller.install()
    }

    // MARK: - Initializers

    /// Initializes the macOS installer with a virtual machine and its associated restore image.
    ///
    /// This initializer verifies the existence of the restore image specified in the template
    /// and associates the installer with the virtual machine's state manager for tracking progress.
    ///
    /// - Parameter virtualMachine: A `VirtualMachine` instance configured with the provided `Template`.
    /// - Throws:
    ///   - `VZKitError.missingMacImage`: If the required restore image is not available.
    ///   - Any errors thrown by the superclass initializer.
    public init(virtualMachine: VirtualMachine<Template>) throws {
        let restoreImageURL = virtualMachine.template.removableDiskImage
        
        guard let restoreImageURL else {
            throw VZKitError.missingMacImage
        }
        
        self.vzKitStateCoordinator = virtualMachine.stateCoordinator
        
        self.vzMacOSInstaller = VZMacOSInstaller(
            virtualMachine: virtualMachine.vzVirtualMachine,
            restoringFromImageAt: restoreImageURL
        )
    }

    /// Initializes the macOS installer asynchronously with a virtual machine and a specified restore image URL.
    ///
    /// This initializer validates the restore image for macOS compatibility and ensures the version matches
    /// the template's requirements. It associates the installer with the virtual machine's state manager for
    /// tracking progress.
    ///
    /// - Parameters:
    ///   - virtualMachine: A `VirtualMachine` instance configured with the provided `Template`.
    ///   - url: The file URL of the macOS restore image.
    /// - Throws:
    ///   - `VZKitError.macUnsupportedImage`: If the restore image is incompatible with macOS.
    ///   - `VZKitError.wrongMacImageVersion`: If the restore image version does not match the template.
    ///   - Any errors thrown during restore image validation or superclass initialization.
    public init(virtualMachine: VirtualMachine<Template>, restoringFromImageAt url: URL) async throws {
        
        switch virtualMachine.template.operatingSystem {
        case .linux:
            throw VZKitError.macUnsupportedImage

        case .macos(let version):
            let restoreImage = try await VZMacOSRestoreImage.load(from: url)
            
            guard restoreImage.isSupported else {
                throw VZKitError.macUnsupportedImage
            }
            
            guard restoreImage.osVersion.major == version.major else {
                throw VZKitError.wrongMacImageVersion(version, restoreImage.osVersion)
            }
        }
        
        self.vzKitStateCoordinator = virtualMachine.stateCoordinator
        
        self.vzMacOSInstaller = VZMacOSInstaller(
            virtualMachine: virtualMachine.vzVirtualMachine,
            restoringFromImageAt: url
        )
    }
}
