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
> - **Building**: Xcode with the macOS 27 SDK. The framework still runs on macOS 14; the SDK is needed for the display of the Apple back-end, which uses `VZVirtualMachineViewAdaptor` where available.
>
> Some features need more at run time: removable drives on the Apple back-end and nested virtualization need macOS 15, and nested virtualization also needs an M3 or later. `support(for:options:)` tells whether the current Mac qualifies (see below).

---

## Back-ends

Both back-ends implement the same `VirtualMachine` protocol and are driven by the same templates, actions and execution states. What only one of them understands goes into its options. Pick the one that fits the guest:

| | Apple Virtualization | QEMU |
|---|---|---|
| **Type** | `AppleVirtualMachine` | `QEMUVirtualMachine` |
| **Options** | `AppleMachineOptions` | `QEMUMachineOptions` |
| **Guests** | macOS, Linux | Linux, Windows (and other UEFI guests) |
| **Architectures** | arm64 | arm64 (hardware accelerated), x86_64 (emulated) |
| **Display** | `AppleFramebufferView` | `QEMUFramebufferView` |
| **Disks** | virtio, USB, NVMe (Linux guests) | virtio, NVMe, USB (optical discs on USB) |
| **Networking** | NAT, bridged | NAT |
| **Extras** | Rosetta, nested virtualization, directory sharing, microphone input, macOS installation | TPM 2.0, Secure Boot firmware, reset |
| **Shared** | Removable drives at run time, audio output, power button, pause and resume |

### Apple Virtualization
Built on Apple's `Virtualization.framework`. It is the natural choice for macOS guests and for Linux guests that benefit from Rosetta or directory sharing. Apps using it need the `com.apple.security.virtualization` entitlement; bridged networking also needs `com.apple.vm.networking`, a restricted entitlement Apple grants on request.

### QEMU
Built on a sandboxed, embedded build of QEMU, for guests Apple Virtualization cannot run, most notably **Windows**.

- **Process model.** The emulator runs in an XPC service embedded in the framework, never in your app's process. Files are opened by your app and handed over as open file descriptors, so the emulator never needs file-access entitlements of its own.
- **Display.** A native Swift client renders the guest display; no third-party display libraries are linked into your app.
- **Explicit hardware.** Nothing is derived from the guest operating system. A guest gets the disk interface, display device and clock it is given, so a machine keeps describing the same hardware in every release.
- **Windows.** Windows has no virtio drivers until they are installed, so give it hardware it supports out of the box: an NVMe system disk, the install media on USB, `displayDevice: .virtioGPUWithFramebuffer`, `clock: .localTime` and `guestDrawsPointer: true` (see the example below). Once the virtio drivers are installed, set `displayDevice` to `.virtioGPU`.
- **Machine options.** `QEMUMachineOptions` selects the architecture, the display device, the hardware clock and how the pointer is drawn. A TPM 2.0 and Secure Boot capable firmware are capabilities of the template (`.tpm`, `.secureBoot`).

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
A template describes a machine in terms every back-end shares: processors, memory, disks, network, display and optional capabilities. Conform your own type to `TransferableTemplate`:

```swift
import VirtualizationKit

struct MyTemplate: TransferableTemplate {
    var id = UUID()
    var name = "MySampleVM"
    var storage: [DiskImage] = []
    var networkTopology: NetworkTopology = .nat()
    var performancePreset: PerformancePreset = .balanced
    var display = DisplaySize(width: 1280, height: 720)
    var optionalCapabilities: [OptionalCapability] = []
}
```

### Disks
A machine has any number of disks. Each one says where its file lives, what the guest sees and whether the firmware boots from it:

```swift
var template = MyTemplate()

template.storage = [
    // Created by the framework inside the machine's directory, 64 GiB, sparse.
    DiskImage(location: .managed(size: 64 << 30), interface: .virtio, bootOrder: 1),

    // A file the user picked. It is stored as a security-scoped bookmark,
    // so the template still finds it after a relaunch inside the App Sandbox.
    DiskImage(
        location: try .external(fileAt: isoURL, readOnly: true),
        kind: .optical,
        interface: .usb,
        bootOrder: 0
    )
]
```

The interface is always explicit. `bootOrder` is passed to the firmware by the QEMU back-end; Virtualization.framework has no such setting, so the Apple back-end presents the disks in that order instead.

### Running a machine
```swift
import VirtualizationKit
import Combine

// 1. Create the machine with the back-end of your choice
let vm = try await AppleVirtualMachine(template: template)

// 2. Subscribe to state updates. The current state arrives right away, then every change.
//    In SwiftUI, reading `vm.executionState` is enough: the coordinators are @Observable.
var cancellables = Set<AnyCancellable>()
vm.statePublisher
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

// 4. Later: ask the guest to shut down, or power it off at once
try await vm.execute(action: .requestStop)
try await vm.execute(action: .stop)
```

The same code drives a QEMU machine; only the type changes. Each back-end has a few actions of its own: `.install` and `.macOSRecovery()` on the Apple back-end, `.reset` on the QEMU one.

`execute(action:)` returns once the operation is done. The state follows what the machine reports, so it can be updated a moment later; observe it rather than reading it right after the call.

### Machine options
`init(template:)` uses the default options of the back-end. Both defaults describe the same machine, a 64-bit ARM Linux guest, which is also the one case where a template runs on either back-end unchanged. Anything else is stated in the options:

```swift
// A macOS guest, installed from a restore image the user picked
let mac = try await AppleVirtualMachine(
    template: template,
    options: .init(platform: try await .macOS(restoreImageAt: ipswURL))
)

try await mac.execute(action: .install)
```

To show the restore image before creating the machine (its macOS version and build, whether this Mac can run it, and the minimum processors and memory it needs), load it first and create the platform from it:

```swift
let image = try await MacOSRestoreImage.load(from: ipswURL)
let options = AppleMachineOptions(platform: try .macOS(restoreImage: image))
```

```swift
// A Windows 11 guest
var windows = MyTemplate()

windows.optionalCapabilities = [.tpm, .secureBoot, .audioOutputDevice]
windows.storage = [
    DiskImage(location: .managed(size: 64 << 30), interface: .nvme, bootOrder: 1),
    DiskImage(location: try .external(fileAt: isoURL, readOnly: true), kind: .optical, interface: .usb, bootOrder: 0)
]

let vm = try await QEMUVirtualMachine(
    template: windows,
    options: .init(
        displayDevice: .virtioGPUWithFramebuffer,
        clock: .localTime,
        guestDrawsPointer: true
    )
)
```

> [!IMPORTANT]
> Options are part of the identity of a machine, just like its template. Persist the two together: a machine restored with different options is a different machine.

### Removable drives
A disk image can be attached to a running machine as a removable drive, as a USB stick or disc would be plugged in, and detached again. The machine needs the `.xhciUSBHotSwap` capability, on both back-ends:

```swift
template.optionalCapabilities.append(.xhciUSBHotSwap)

let drive = try await vm.attachRemovableDrive(imageAt: imageURL)
// ...
try await vm.detachRemovableDrive(identifiedBy: drive)
```

### Checking what a back-end supports
A template can ask for more than a back-end offers. Ask before you build, for instance to decide what your UI shows:

```swift
// .supported, .unsupported(why) or .unavailable(what is missing)
switch AppleVirtualMachine<MyTemplate>.support(for: .rosetta, options: options) {
case .supported:                     print("Rosetta can be used")
case .unavailable(.hostSoftware):    print("Rosetta has to be installed first")
case .unsupported(.guestPlatform):   print("Rosetta only runs in Linux guests")
case .unsupported, .unavailable:     print("Rosetta cannot be used here")
}

// Throws a localized error for the first thing the back-end cannot honour.
// Nothing is created or modified on disk.
try QEMUVirtualMachine.validate(windows, options: options)
```

The initializers run the same validation before they do anything else, so a rejected template leaves no files behind.

To capture creation errors instead of throwing them, for instance to present them later in SwiftUI, use `VZKitResult`:

```swift
let result = await VZKitResult(QEMUVirtualMachine<MyTemplate>.self, using: windows, options: options)
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
- `PerformancePreset` offers ready-made processor and memory sizes, resolved against the host every time a machine is created. The size of a disk is set on the disk itself.
- Low-level error codes become approachable, localized descriptions, in English and Italian.

  **Example:**
  ```swift
  do {
      let mac = try await AppleVirtualMachine(template: template, options: options)

  } catch {

      // Prints an error description that is actually useful like
      // "The Virtual Machine has been created using a macOS 15.2.0
      //  restore image, but the currently selected image’s version is 14.6.1"
      print("Failed to create VM: \(error.localizedDescription)")
  }
  ```

- Errors thrown by the framework are `VZKitError` values, so a specific failure can be handled on its own:

  ```swift
  do {
      let vm = try await AppleVirtualMachine(template: template)

  } catch VZKitError.unavailableFeature(.rosetta, .hostSoftware) {
      // Offer to install Rosetta, then try again
  }
  ```

  A template is checked when the machine is created, so that is where a missing capability or an unsuitable restore image is reported.

---

## Migrating from 1.x

2.0 changes how a machine is described, and parts of the runtime API: some actions, the state publisher and removable drives. See [MIGRATION.md](MIGRATION.md) for the full list of changes and how to keep existing machines.
