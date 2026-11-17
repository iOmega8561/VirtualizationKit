//
//  Copyright 2026 Giuseppe Rocco
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

/// The size of the guest display when the virtual machine is powered on, in pixels.
///
/// This is where the display starts, not a limit: a guest is free to change its resolution later, and
/// the framebuffer views can ask it to follow the size of their container.
///
/// Dimensions are clamped to a range every backend can provide, so a value of this type is always
/// usable as is.
///
/// ```swift
/// let display = DisplaySize(width: 1920, height: 1080)
/// ```
public struct DisplaySize: Transferable {

    /// The smallest display a virtual machine can start with.
    public static let minimum = DisplaySize(width: 640, height: 480)

    /// The largest display a virtual machine can start with.
    public static let maximum = DisplaySize(width: 7680, height: 4320)

    /// The width of the display, in pixels.
    public let width: Int

    /// The height of the display, in pixels.
    public let height: Int

    /// Creates a display size.
    ///
    /// - Parameters:
    ///   - width: The width, in pixels. Clamped to the range between `minimum` and `maximum`.
    ///   - height: The height, in pixels. Clamped to the range between `minimum` and `maximum`.
    public init(width: Int, height: Int) {
        self.width = min(max(width, 640), 7680)
        self.height = min(max(height, 480), 4320)
    }

    // MARK: - Codable

    /// The keys of the encoded form.
    private enum CodingKeys: String, CodingKey {
        case width, height
    }

    /// Decodes a display size, clamping it like the initializer does.
    ///
    /// - Parameter decoder: The decoder to read from.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            width: try container.decode(Int.self, forKey: .width),
            height: try container.decode(Int.self, forKey: .height)
        )
    }
}
