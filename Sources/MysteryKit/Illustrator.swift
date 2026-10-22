import CoreGraphics
import Foundation
import ImageIO
import ImagePlayground
import UniformTypeIdentifiers

/// Paints the case on-device with Image Playground and keeps the pictures on disk,
/// so a case only ever has to be illustrated once.
public actor Illustrator {
    public enum Subject: Hashable, Sendable {
        case cover, owner, item
        case suspect(Int)
        case room(RoomRole)
        case card(String)

        var key: String {
            switch self {
            case .cover: "cover"
            case .owner: "owner"
            case .item: "item"
            case .suspect(let id): "suspect-\(id)"
            case .room(let r): "room-\(r.rawValue)"
            case .card(let id): "card-\(id)"
            }
        }
    }

    public enum Failure: Error, Sendable {
        /// Image Playground only paints while the app is in front. Try again when it is.
        case needsForeground
        case unavailable
    }

    private let mystery: Case
    private let folder: URL
    private var creator: ImageCreator?
    private var isUnavailable = false
    private var inFlight: [Subject: Task<URL, Error>] = [:]

    public init(mystery: Case) {
        self.mystery = mystery
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        folder = caches.appending(path: "Pawprints/cases/\(mystery.seed)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    public nonisolated func cached(_ subject: Subject) -> URL? {
        let url = file(for: subject)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public nonisolated func file(for subject: Subject) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appending(path: "Pawprints/cases/\(mystery.seed)/\(subject.key).jpg")
    }

    public nonisolated func prompt(for subject: Subject) -> String? {
        let m = mystery
        switch subject {
        case .cover:
            return "\(m.coverLook), cosy storybook scene"
        case .owner:
            return "\(m.ownerLook), friendly portrait"
        case .item:
            return "\(m.itemLook), treasure, still life"
        case .suspect(let id):
            return "\(m.suspect(id).look), character portrait"
        case .room(let role):
            return "\(m.room(role).look), cosy storybook interior, no people"
        case .card(let id):
            if let p = m.card(id).imagePrompt { return p }
            if id == CardID.trace { return m.trace.illustration }
            return nil
        }
    }

    /// The same picture as a job for the painter helper.
    public nonisolated func job(for subject: Subject) -> PaintJob? {
        let prompts = [prompt(for: subject), fallbackPrompt(for: subject)].compactMap { $0 }
        return prompts.isEmpty ? nil : PaintJob(prompts: prompts, output: file(for: subject))
    }

    /// Returns the picture for a subject, painting it first if needed (in this process).
    public func image(for subject: Subject) async throws -> URL {
        if let url = cached(subject) { return url }
        if let running = inFlight[subject] { return try await running.value }
        let task = Task { try await paint(subject) }
        inFlight[subject] = task
        defer { inFlight[subject] = nil }
        return try await task.value
    }

    /// A plainer prompt for when Image Playground turns the first one down, which it
    /// does for anything it thinks might depict a real person.
    public nonisolated func fallbackPrompt(for subject: Subject) -> String? {
        let m = mystery
        switch subject {
        case .cover: return "\(m.place.replacingOccurrences(of: "the ", with: "")) at night, cosy storybook scene"
        case .owner: return "a friendly old \(m.ownerSpecies)"
        case .item: return "\(m.item.replacingOccurrences(of: "the ", with: "")), still life"
        case .suspect(let id): return "a cute \(m.suspect(id).species) in old-fashioned clothes"
        case .room(let role): return "a cosy empty \(m.room(role).name.replacingOccurrences(of: "the ", with: "").lowercased()) at night"
        case .card(let id): return "\(m.card(id).title.lowercased()), still life"
        }
    }

    private func paint(_ subject: Subject) async throws -> URL {
        guard !isUnavailable else { throw Failure.unavailable }
        let prompts = [prompt(for: subject), fallbackPrompt(for: subject)].compactMap { $0 }
        for text in prompts {
            do {
                let creator = try await creatorInstance()
                for try await created in creator.images(for: [.text(text)], style: .illustration, limit: 1) {
                    let url = file(for: subject)
                    try write(created.cgImage, to: url)
                    return url
                }
            } catch let error as ImageCreator.Error {
                switch error {
                case .backgroundCreationForbidden: throw Failure.needsForeground
                case .notSupported, .unavailable: isUnavailable = true; throw Failure.unavailable
                default: continue // refused or failed: try the plainer prompt
                }
            }
        }
        throw Failure.unavailable
    }

    /// Lets go of Image Playground. While an `ImageCreator` is alive, other apps on the Mac
    /// (apfel included) can't use the on-device language model, so only hold one while painting.
    public func release() {
        guard inFlight.isEmpty else { return }
        creator = nil
    }

    private func creatorInstance() async throws -> ImageCreator {
        if let creator { return creator }
        let made = try await ImageCreator()
        creator = made
        return made
    }

    /// Where a picture that doesn't belong to any one case is kept, such as the title screen.
    public static func sharedFile(key: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "Pawprints", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        return caches.appending(path: "\(key).jpg")
    }

    /// Paints a shared picture in this process.
    public static func shared(key: String, prompt: String, side: Int = 768) async throws -> URL {
        let url = sharedFile(key: key)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        do {
            let creator = try await ImageCreator()
            for try await created in creator.images(for: [.text(prompt)], style: .illustration, limit: 1) {
                try ImageFiles.writeJPEG(created.cgImage, to: url, side: side)
                return url
            }
        } catch ImageCreator.Error.backgroundCreationForbidden {
            throw Failure.needsForeground
        }
        throw Failure.unavailable
    }

    private nonisolated func write(_ image: CGImage, to url: URL) throws {
        try ImageFiles.writeJPEG(image, to: url, side: 768)
    }
}
