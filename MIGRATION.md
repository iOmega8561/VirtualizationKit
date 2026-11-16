# Migrating from 1.x to 2.0

2.0 changes how a machine is described. A template now holds what every back-end shares, and each back-end has an options type for what only it understands. Nothing is derived from the guest operating system anymore: the hardware a guest needs is stated explicitly.

The runtime API (actions, execution states, framebuffer views) is unchanged.

## Templates and options

| 1.x | 2.0 |
|---|---|
| `bootableInstallMedia` | A `DiskImage` in `storage` with `kind: .optical`. For macOS, `AppleMachineOptions.Platform.macOS(restoreImageAt:)` |
| `performancePreset.diskSize`, `.custom(_, _, diskSize)` | `DiskImage.Location.managed(size:)` |
| `operatingSystem: .linux` | Nothing: it is the default of both back-ends |
| `operatingSystem: .macos(version:)` | `AppleMachineOptions(platform: .macOS(version:restoreImage:))` |
| `operatingSystem: .windows` | An NVMe system disk plus `QEMUMachineOptions(displayDevice: .virtioGPUWithFramebuffer, clock: .localTime, guestDrawsPointer: true)` |
| `QEMUMachineOptions.displayWidth` / `displayHeight` | `display: DisplaySize` in the template (1920×1200 was the fixed size of macOS guests, 1280×720 of the others) |
| `QEMUMachineOptions.includesTPM` / `usesSecureBootFirmware` | `.tpm` / `.secureBoot` in `optionalCapabilities` |
| `DisplayDevice.automatic` | `.virtioGPU`, or `.virtioGPUWithFramebuffer` for x86_64 and for Windows before its drivers are installed |
| `VirtualMachine.init(template:)` | Still available, and uses the default options of the back-end. Conforming types implement `init(template:options:)` instead |
| `VZKitResult(_:using:options:)` (QEMU only) | `VZKitResult(_:using:options:)` for any back-end, with the options optional |

## Capabilities

| 1.x | 2.0 |
|---|---|
| `OptionalCapability.featureScope` | `VirtualMachine.support(for:options:)`, whose answer carries the reason: `.unsupported(Limitation)` or `.unavailable(MissingComponent)` |
| `OptionalCapability.isNestedVirtualizationSupported` | `AppleVirtualMachine<T>.support(for: .nestedVirtualization, options:)` |
| Errors `unsupportedFeature(_)` / `unavailableFeature(_)` | The same errors carry the reason, and their messages state it |
| Hot-plugging a USB drive without a USB controller: "unsupported" | `featureNotEnabled(.xhciUSBHotSwap)` |

Validation has become stricter on the Apple back-end. Rosetta or nested virtualization on a macOS guest, and USB hot-plug on a host older than macOS 15, used to be ignored silently. They are now rejected, before any file is written. Call `validate(_:options:)` to find out ahead of time.

## Execution state

- An Apple machine whose network attachment is disconnected keeps its state (usually `.running`) instead of switching to `.error`. The disconnect is logged. `.error` now always means the machine has stopped.
- `ExecutionState` encodes `.error` and `.installing` together with their value, and decodes them. The other states are encoded as before, and states stored by 1.x decode.

## Existing machines

**Disks.** The system disk of a 1.x machine is the file `Disk.img` in its directory. A managed disk is now named after its identifier, so rename the file to `Disk-<disk id>.img` once. Giving that disk the identifier of the template also keeps the NVMe serial number of QEMU machines.

**Options.** Persist the options of a machine next to its template. A 1.x machine created with `.macos` needs `AppleMachineOptions(platform: .macOS(...))` from now on, and a Windows machine the QEMU options listed above; created with the default options instead, they would be rebuilt as Linux machines.

**Stored values.** `PerformancePreset` and `QEMUMachineOptions` values persisted by 1.x still decode, with two things to watch:

- Keys that no longer exist are ignored. That includes `includesTPM` and `usesSecureBootFirmware`: move them to the template's capabilities, or the machine loses its TPM and Secure Boot firmware.
- A display device stored as `automatic` decodes to `.virtioGPU` on aarch64 and `.virtioGPUWithFramebuffer` on x86_64. That matches what 1.x chose for every guest except Windows on aarch64, which needs `.virtioGPUWithFramebuffer` set explicitly.
