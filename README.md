# VirtualizationKit

## Introduction

`VirtualizationKit` is designed to provide a more straightforward and accessible way to use Apple's `Virtualization.framework`. This framework abstracts the complexities of virtualization, allowing developers to focus on their applications without getting bogged down in intricate configurations.

## Key Points

- Simplification as the Primary Goal
  - The framework focuses on abstracting the complexities of `Virtualization.framework`, making it easier for developers to get started.
  - Developers can achieve common virtualization tasks without deep knowledge of the underlying system.
  - The starting point is a standardized, customizable data structure that defines the specific of the virtual machine (The `Template`).

- `Virtualization.framework` as the "Customizable Core"
  - Advanced customization is already possible through `Virtualization.framework`.
  - This framework acts as a utility layer, prioritizing simplicity and providing opinionated defaults for common use cases.

- Targets Developers who:
  - Are not experts in virtualization or system-level APIs.
  - Want to get started quickly without diving into low-level details.
  - Prefer simplicity and abstraction over extreme flexibility, but without missing out on incredibly powerful features.

---

## Design Implications

- Minimal API Surface
  - The framework provides a minimal, intuitive API that focuses on the most common virtualization scenarios.
  - Advanced features from `Virtualization.framework` are not duplicated but remain accessible for users who need them.

- Opinionated Design
  - The framework assumes sensible defaults to minimize setup and configuration time.
  - Repetitive tasks and verbose configurations are encapsulated in high-level methods and engineering patterns.

- Clear Boundaries
  - The framework is a facilitator, and for most use-cases, can be a replacement, for `Virtualization.framework`.
  - `VirtualizationKit` is not aiming to be an "doall-hypervisor-swiss-knife", so not everyone will be satisfied with the available features.

- Strong Documentation
  - Easy-to-follow guides, real-world examples, and step-by-step workflows for common use cases will help developers make the most of the framework.

---

## Potential API Design Goals

### 1. Helper Classes and Methods
- Simplify complex configurations with intuitive high-level APIs.
  
  **Example:**
  ```swift

  let myAwesomeTemplate = Template(name: ..., os: .linux, ram: 4096, cpu: 3, ...)

  do {
     let vm = VirtualMachine(template: myAwesomeTemplate)

  } catch { print(error.localizedDescription) }
  
  vm.installOS(from: "installer.iso") { progress in
      print("Installation progress: \(progress)%")
  }
  ```

### 2. Sensible Defaults
- Provide preconfigured settings for common virtualization scenarios, reducing boilerplate code.

### 3. Error Handling
- Abstract detailed error codes and provide user-friendly error messages with actionable suggestions.

  **Example:**
  ```swift
  do {
      try await vm.execute(command: .start)
  
  } catch { print("Failed to start VM: \(error.localizedDescription)") }
  ```

### 4. High-Level Utilities
- Offer utilities to automate repetitive tasks:
  - Automatically create disk images.
  - Set up shared folders between host and guest.
  - Automatically handle system input capture.
  - Refine configuration details based on the guest Operating System.
