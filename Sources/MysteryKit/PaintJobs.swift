import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A picture for the painter helper to make. The game writes these into a queue folder;
/// "Pawprints Painter" paints them and quits as soon as the queue is empty.
///
/// Why a helper at all: while a process that has used Image Playground is alive, macOS keeps
/// Image Playground's extension running for it, and command-line clients of the on-device
/// language model (apfel among them) fail with GenerationError -1. Painting in a short-lived
/// helper keeps that window to the few seconds of actual painting.
public struct PaintJob: Codable, Sendable {
    /// Tried in order until one is accepted.
    public var prompts: [String]
    public var output: String
    public var side: Int

    public init(prompts: [String], output: URL, side: Int = 768) {
        self.prompts = prompts
        self.output = output.path
        self.side = side
    }

    public static var queueFolder: URL {
        let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "Pawprints/queue", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Marker written next to the output when every prompt was refused.
    public static func failureMarker(for output: URL) -> URL {
        output.appendingPathExtension("failed")
    }

    /// Adds the job to the queue. Urgent jobs sort first, so they are painted next.
    public func enqueue(urgent: Bool = false) throws {
        let name = "\(urgent ? "0" : "1")-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(6)).json"
        let data = try JSONEncoder().encode(self)
        let temp = Self.queueFolder.appending(path: "." + name)
        try data.write(to: temp)
        try FileManager.default.moveItem(at: temp, to: Self.queueFolder.appending(path: name))
    }

    /// Drops every waiting job, e.g. when a new case replaces the old one.
    public static func clearQueue() {
        for file in pending() { try? FileManager.default.removeItem(at: file) }
    }

    /// Jobs still waiting, oldest (or most urgent) first.
    public static func pending() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: queueFolder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

public enum ImageFiles {
    /// Scales a painting down to `side` pixels and saves it as JPEG, atomically.
    public static func writeJPEG(_ image: CGImage, to url: URL, side: Int) throws {
        let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        let temp = url.deletingLastPathComponent().appending(path: ".\(UUID().uuidString).jpg")
        guard let scaled = context.makeImage(),
              let dest = CGImageDestinationCreateWithURL(temp as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(dest, scaled, [kCGImageDestinationLossyCompressionQuality: 0.88] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: temp, to: url)
    }
}
