import Foundation
import ImageIO

public enum PetPose: String, CaseIterable {
    case idle, walk, working, waiting, done
}

public struct SpriteFrames {
    public static let maxDimension = 4096
    public static let maxFrames = 240
    public static let maxTotalPixels = 64_000_000
    private static let fallbackDelay = 0.1

    public let images: [CGImage]
    public let durations: [Double]

    public var totalDuration: Double { durations.reduce(0, +) }

    public static func load(url: URL, maxTotalPixels: Int = SpriteFrames.maxTotalPixels) -> SpriteFrames? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        var images: [CGImage] = []
        var durations: [Double] = []
        var totalPixels = 0
        for index in 0..<min(CGImageSourceGetCount(source), maxFrames) {
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            guard image.width <= maxDimension, image.height <= maxDimension else { return nil }
            totalPixels += image.width * image.height
            guard totalPixels <= maxTotalPixels else { return nil }
            images.append(image)
            durations.append(delay(of: source, at: index))
        }
        return images.isEmpty ? nil : SpriteFrames(images: images, durations: durations)
    }

    private static func delay(of source: CGImageSource, at index: Int) -> Double {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
        let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        let png = properties?[kCGImagePropertyPNGDictionary] as? [CFString: Any]
        let value = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
            ?? gif?[kCGImagePropertyGIFDelayTime] as? Double
            ?? png?[kCGImagePropertyAPNGUnclampedDelayTime] as? Double
            ?? png?[kCGImagePropertyAPNGDelayTime] as? Double
            ?? fallbackDelay
        return value < 0.02 ? fallbackDelay : value
    }
}

public struct Skin: Equatable {
    public let id: String
    public let name: String
    public let height: Double
    public let directory: URL
    let files: [PetPose: URL]

    public func url(for pose: PetPose) -> URL {
        files[pose] ?? files[.idle]!
    }
}

public enum SkinLoader {
    public static let defaultHeight = 96.0
    public static let heightRange = 16.0...512.0
    private static let extensions = ["gif", "png"]

    public static func load(directory: URL) -> Skin? {
        guard let entries = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return nil }
        var files: [PetPose: URL] = [:]
        for pose in PetPose.allCases {
            let candidates = entries.filter {
                $0.deletingPathExtension().lastPathComponent.lowercased() == pose.rawValue
                    && extensions.contains($0.pathExtension.lowercased())
            }
            files[pose] = candidates
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .first { SpriteFrames.load(url: $0) != nil }
        }
        guard files[.idle] != nil else { return nil }

        var name = directory.lastPathComponent
        var height = defaultHeight
        if let data = try? Data(contentsOf: directory.appendingPathComponent("skin.json")),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let custom = json["name"] as? String, !custom.isEmpty { name = custom }
            if let custom = json["height"] as? Double {
                height = min(max(custom, heightRange.lowerBound), heightRange.upperBound)
            }
        }
        return Skin(id: directory.lastPathComponent, name: name, height: height, directory: directory, files: files)
    }

    public static func list(in root: URL) -> [Skin] {
        let entries = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return entries
            .compactMap(load(directory:))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
