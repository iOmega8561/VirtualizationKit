# VirtualizationKit
`VirtualizationKit` is a macOS framework for easy virtualization that accommodates different back-ends behind one interface. It ships with two: **Apple Virtualization** and **QEMU**. The primary goal is to offer a streamlined interface to manage virtual machines without needing to deal with the higher complexity that comes with standard virtualization solutions.

---

## Design Implications
- A **minimal** and **simple to use** API that wraps the complexity of virtualization and reduces boilerplate code.
- Defaults that *“just work”* for the majority of use cases, from basic Linux VMs to more complex setups.
- Avoids **redundancy**, by not replicating advanced scenarios and use cases from the various back-ends.
- **Sandbox-first**: both back-ends work inside the App Sandbox, so apps using them can be distributed through the Mac App Store.

> [!TIP]
> **Target Audience**
> - **Developers new to Virtualization**: Gentle learning curve for those unfamiliar with system-level APIs.
> - **Teams seeking quick setup**: When spinning up VMs should be simple and repeatable, without fuss.
> - **Users wanting abstraction**: Consistent, streamlined API over multiple vendor-specific solutions.

---

## Requirements

> [!WARNING]
> To be able to use this framework, please make sure your system meets the following requirements:
>
> - **Processor**: Apple Silicon (M1, M2, or newer)
> - **Operating System**: macOS Sonoma 14.0 or later

---

## Back-ends

Both back-ends implement the same `VirtualMachine` protocol and are driven by the same templates, actions and execution states. Pick the one that fits the guest:

| | Apple Virtualization | QEMU |
|---|---|---|
| **Type** | `AppleVirtualMachine` | `QEMUVirtualMachine` |
| **Guests** | macOS, Linux | Linux, Windows (and other UEFI guests) |
| **Architectures** | arm64 | arm64 (hardware accelerated), x86_64 (emulated) |
| **Display** | `AppleFramebufferView` | `QEMUFramebufferView` |
| **Networking** | NAT, bridged | NAT |
| **Extras** | Rosetta, directory sharing, macOS installation | TPM 2.0, Secure Boot firmware |
| **Shared** | Removable USB drives at run time, audio output, pause and resume |

### Apple Virtualization
Built on Apple's `Virtualization.framework`. It is the natural choice for macOS guests and for Linux guests that benefit from Rosetta or directory sharing. Apps using it need the `com.apple.security.virtualization` entitlement.

### QEMU
Built on a sandboxed, embedded build of QEMU, for guests Apple Virtualization cannot run, most notably **Windows**.

- **Process model.** The emulator runs in an XPC service embedded in the framework, never in your app's process. Files are opened by your app and handed over as open file descriptors, so the emulator never needs file-access entitlements of its own.
- **Display.** A native Swift client renders the guest display; no third-party display libraries are linked into your app.
- **Windows.** Windows guests (`OperatingSystem.windows`) get hardware Windows supports out of the box: an NVMe disk, a framebuffer display and USB install media. Once the virtio drivers are installed, set `displayDevice` to `.virtioGPU`.
- **Machine options.** `QEMUMachineOptions` selects the architecture, the initial display size, the display device, a TPM 2.0 and Secure Boot capable firmware.

> [!IMPORTANT]
> **Using the QEMU back-end in an app**
> 1. Build the emulator payload once with `Third-Party/setup-dependencies.sh` (requires Homebrew's `meson`, `ninja`, `pkg-config`, `autoconf`, `automake` and `libtool`). The framework embeds it when it is built.
> 2. Embed the framework, then add a *Run Script* phase **after** “Embed Frameworks” that runs `QEMUSupport/resign-embedded-helper.sh`. It re-signs the embedded helper, its launcher and its libraries with your identity and their own entitlements. Set `ENABLE_USER_SCRIPT_SANDBOXING = NO` for that target.
> 3. Your app needs no additional entitlements for QEMU. If guests talk to devices on your local network, add `NSLocalNetworkUsageDescription` to its `Info.plist`.

> [!NOTE]
> QEMU and its dependencies are licensed separately from this framework (QEMU under the GPL v2). They run in their own process and are never linked into your app, but distributing them comes with their licence obligations.

---

## Usage

### Templates
A template describes a machine independently of the back-end that runs it. Conform your own type to `TransferableTemplate`:

```swift
import VirtualizationKit

struct MyTemplate: TransferableTemplate {
    var id = UUID()
    var name = "MySampleVM"
    var bootableInstallMedia: URL? = URL(filePath: "/path/to/installer.iso")
    var operatingSystem: OperatingSystem = .linux
    var networkTopology: NetworkTopology = .nat()
    var performancePreset: PerformancePreset = .balanced
    var optionalCapabilities: [OptionalCapability] = []
}
```

### Running a machine
```swift
import VirtualizationKit
import Combine

// 1. Create the machine with the back-end of your choice
let vm = try await AppleVirtualMachine(template: MyTemplate())

// 2. Subscribe to state updates
var cancellables = Set<AnyCancellable>()
vm.stateCoordinator.stateSubject
    .sink { state in
        switch state {
        case .installing(let progress): print("Installation at: \(progress)")
        case .running:                  print("VM is running")
        case .stopped:                  print("VM stopped")
        default:                        break
        }
    }
    .store(in: &cancellables)

// 3. Start it
try await vm.execute(action: .start())
```

The same code drives a QEMU machine; only the type changes. Back-end specific settings go into the options:

```swift
var windows = MyTemplate()
windows.operatingSystem = .windows

let vm = try await QEMUVirtualMachine(
    template: windows,
    options: .init(architecture: .aarch64, includesTPM: true, usesSecureBootFirmware: true)
)

try await vm.execute(action: .start())
```

To capture creation errors instead of throwing them, for instance to present them later in SwiftUI, use `VZKitResult`:

```swift
let result = await VZKitResult(QEMUVirtualMachine<MyTemplate>.self, using: windows, options: .init())
```

### Showing the display
```swift
import SwiftUI

struct MachineView: View {
    let vm: QEMUVirtualMachine<MyTemplate>

    var body: some View {
        QEMUFramebufferView(
            virtualMachine: vm,
            automaticallyReconfiguresDisplay: true,
            disablesInputRedirection: false
        )
    }
}
```

`AppleFramebufferView` takes an `AppleVirtualMachine` with the same parameters.

### Simplified Management
- Ready-to-use configurations for common virtualization needs—like typical CPU, memory, and disk settings.
- Mask low-level error codes with approachable, localized descriptions and actionable suggestions.

  **Example:**
  ```swift
  do {
      try await vm.execute(action: .start())

  } catch {

      // Prints an error description that is actually useful like
      // "The Virtual Machine has been created using a macOS 15.2
      //  restore image, but the currently selected image’s version is 12.6"
      print("Failed to start VM: \(error.localizedDescription)")
  }
  ```
