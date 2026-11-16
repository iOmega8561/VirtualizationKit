# Migrating from 1.x to 2.0

2.0 changes how a machine is described. A template now holds what every back-end shares, and each back-end has an options type for what only it understands. Nothing is derived from the guest operating system anymore: the hardware a guest needs is stated explicitly.

Parts of the runtime API changed too: some actions, the state publisher and removable drives. The framebuffer views are unchanged.

> [!NOTE]
> Building 2.0 needs Xcode with the macOS 27 SDK. The framework still runs on macOS 14.

## Templates and options

| 1.x | 2.0 |
|---|---|
| `bootableInstallMedia` | A `DiskImage` in `storage` with `kind: .optical`. For macOS, the restore image goes into the options: `AppleMachineOptions.Platform.macOS(restoreImageAt:)` |
| `performancePreset.diskSize`, `.custom(_, _, diskSize)` | `DiskImage.Location.managed(size:)` |
| `operatingSystem: .linux` | Nothing: it is the default of both back-ends |
| `operatingSystem: .macos(version:)` | `AppleMachineOptions(platform: .macOS(version:restoreImage:))` |
| `OperatingSystem(fromImageAt:)` | `AppleMachineOptions.Platform.macOS(restoreImageAt:)`, or `MacOSRestoreImage.load(from:)` followed by `.macOS(restoreImage:)` to show the image first |
| `OperatingSystem.Version` | `AppleMachineOptions.Version`, unchanged otherwise |
| `OperatingSystem.displayName` | `AppleMachineOptions.Platform.displayName`. `fileType` has no successor |
| `operatingSystem: .windows` | An NVMe system disk plus `QEMUMachineOptions(displayDevice: .virtioGPUWithFramebuffer, clock: .localTime, guestDrawsPointer: true)` |
| `QEMUMachineOptions.displayWidth` / `displayHeight` | `display: DisplaySize` in the template (1920×1200 was the fixed size of macOS guests, 1280×720 of the others) |
| `QEMUMachineOptions.includesTPM` / `usesSecureBootFirmware` | `.tpm` / `.secureBoot` in `optionalCapabilities` |
| `DisplayDevice.automatic` | `.virtioGPU`, or `.virtioGPUWithFramebuffer` for x86_64 and for Windows before its drivers are installed |
| `VirtualMachine.init(template:)` | Still available, and uses the default options of the back-end. Conforming types implement `init(template:options:)` instead |
| `VZKitResult(_:using:options:)` (QEMU only) | `VZKitResult(_:using:options:)` for any back-end, with the options optional |

## Actions

| 1.x | 2.0 |
|---|---|
| `QEMUVirtualMachine.requestPowerDown()` | `execute(action: .requestStop)`, on both back-ends |
| `QEMUVirtualMachine.reset()` | `execute(action: .reset)` (QEMU only) |
| `.start(options: VZVirtualMachineStartOptions)` (Apple) | `.start(options: AppleStartOptions(startsFromRecovery:))`. `.macOSRecovery()` is unchanged |
| `attachRemovableUSBDisk(usingImageAt:)` | `attachRemovableDrive(imageAt:)`, part of the `VirtualMachine` protocol |
| `detachRemovableUSBDisk(identifiedBy:)` | `detachRemovableDrive(identifiedBy:)`, part of the `VirtualMachine` protocol |

`.install` on an Apple machine that is not a macOS guest now throws `VZKitError.macPlatformRequired`; it used to return without doing anything.

`ExecutableAction` requires `requestStop`, so custom action types add that case, and its `StartOptions` must be `Sendable`. `canRequestStop` tells whether the guest can react to it (the machine is running).

On the Apple back-end the drive methods used to be marked `@available(macOS 15.0, *)`. They are now available everywhere and check at run time instead: before macOS 15 they throw `unsupportedFeature(.xhciUSBHotSwap, .hostSystem)`, and on a machine created without `.xhciUSBHotSwap` they throw `featureNotEnabled(.xhciUSBHotSwap)`. `if #available` checks around the calls can go. Custom `VirtualMachine` types implement both methods.

The QEMU back-end now requires `.xhciUSBHotSwap` for removable drives too, as the Apple one always did, so a template means the same on both. A QEMU template that attaches drives without it has to add the capability; the emulator command line does not change.

## Capabilities

| 1.x | 2.0 |
|---|---|
| `OptionalCapability.featureScope` | `VirtualMachine.support(for:options:)`, whose answer carries the reason: `.unsupported(Limitation)` or `.unavailable(MissingComponent)` |
| `OptionalCapability.isNestedVirtualizationSupported` | `AppleVirtualMachine<T>.support(for: .nestedVirtualization, options:)` |

`VZKitError` was internal in 1.x, so errors could only be shown. It is public now: match its cases to handle a specific failure. Several messages are more precise than before; in particular, an unsupported capability now says why (the back-end, the guest platform, the version of macOS or the hardware).

Validation has become stricter on the Apple back-end. Rosetta or nested virtualization on a macOS guest, and USB hot-plug on a host older than macOS 15, used to be ignored silently. They are now rejected, before any file is written. Call `validate(_:options:)` to find out ahead of time.

## Execution state

- `stateSubject` is replaced by `statePublisher`, an `AnyPublisher<ExecutionState, Never>`, on the virtual machine and on its state coordinator. Replace `.stateSubject` with `.statePublisher`; nothing else changes for code that only subscribes. Custom `StateCoordinator` types implement `statePublisher` instead.
  - A subscriber receives the current state as soon as it subscribes, then every change. With `stateSubject` it only received later changes, so a `sink` now runs once more, right away.
  - Only the framework changes the state: the publisher has no `send`.
- An Apple machine whose network attachment is disconnected keeps its state (usually `.running`) instead of switching to `.error`. The disconnect is logged. `.error` now always means the machine has stopped.
- `ExecutionState` is no longer `Codable` (it was `Transferable`); it stays `Hashable` and `Sendable`. A stored state is stale as soon as it is read back, since a machine is always `.stopped` when it is created, so stop persisting it.
- When Virtualization.framework reports an error state on its own, an Apple machine now shows `.error(error: VZKitError.internalVirtualizationError)`; it used to be dropped, or turned into `.stopped`. When the specific error is known, the state carries that one instead. Either way, an error state stays until the machine is started again: a `.stopped` reported for the same failure no longer replaces it.

## Concurrency

VirtualizationKit no longer declares Virtualization's `VZVirtualMachine`, `VZVirtualMachineStartOptions`, `VZMacOSVirtualMachineStartOptions` and `VZMacOSRestoreImage` `Sendable`. Those declarations applied to every app importing the framework. Code of your own that passes these objects between actors and relied on them now gets the compiler's diagnostics; Apple does not declare them `Sendable`.

## Existing machines

**Disks.** The system disk of a 1.x machine is the file `Disk.img` in its directory. A managed disk is now named after its identifier, so rename the file to `Disk-<disk id>.img` once. Giving that disk the identifier of the template also keeps the NVMe serial number of QEMU machines.

**One machine per template at a time.** Creating a second virtual machine from a template whose machine is still in use now fails with `VZKitError.machineInUse`, in the same application or another one: the two would have written to the same disks. Release the first machine before creating it again.

**Shared folders.** The folder an Apple machine shares with the guest is named after the template. Separators (`/`, `:`) and leading dots are now replaced, so such a name gets a different folder; other names keep theirs.

**Options.** Persist the options of a machine next to its template. A 1.x machine created with `.macos` needs `AppleMachineOptions(platform: .macOS(...))` from now on, and a Windows machine the QEMU options listed above; created with the default options instead, they would be rebuilt as Linux machines.

**Stored values.** `PerformancePreset` and `QEMUMachineOptions` values persisted by 1.x still decode, with two things to watch:

- Keys that no longer exist are ignored. That includes `includesTPM` and `usesSecureBootFirmware`: move them to the template's capabilities, or the machine loses its TPM and Secure Boot firmware.
- A display device stored as `automatic` decodes to `.virtioGPU` on aarch64 and `.virtioGPUWithFramebuffer` on x86_64. That matches what 1.x chose for every guest except Windows on aarch64, which needs `.virtioGPUWithFramebuffer` set explicitly.
