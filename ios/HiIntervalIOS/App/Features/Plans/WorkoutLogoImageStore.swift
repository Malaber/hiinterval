import Foundation
import HiIntervalCore
import UIKit

/// Stores only user-selected logo images. Plan JSON stores the opaque filename, never photo bytes.
@MainActor
final class WorkoutLogoImageStore {
    static let shared = WorkoutLogoImageStore()

    enum StoreError: LocalizedError {
        case invalidImage

        var errorDescription: String? {
            switch self {
            case .invalidImage: "That photo could not be used as a workout logo."
            }
        }
    }

    private let fileManager: FileManager
    private let directoryURL: URL
    private let maxPixelDimension: CGFloat = 1_024
    /// Filenames are immutable UUIDs; cache avoids a synchronous file read whenever a
    /// plan card is recreated during scrolling or selection changes.
    private let imageCache = NSCache<NSString, UIImage>()

    init(fileManager: FileManager = .default, directoryURL: URL? = nil) {
        self.fileManager = fileManager
        imageCache.countLimit = 24
        imageCache.totalCostLimit = 24 * 1_024 * 1_024
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directoryURL = support
                .appendingPathComponent("HiInterval", isDirectory: true)
                .appendingPathComponent("WorkoutLogos", isDirectory: true)
        }
    }

    /// Decodes, scales, and recompresses picker output before it becomes part of an unsaved draft.
    func preparedPhotoData(from source: Data) throws -> Data {
        guard let image = UIImage(data: source) else { throw StoreError.invalidImage }
        let largestSide = max(image.size.width, image.size.height)
        guard largestSide.isFinite, largestSide > 0 else { throw StoreError.invalidImage }
        let scale = largestSide > maxPixelDimension ? maxPixelDimension / largestSide : 1
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        // `UIGraphicsImageRenderer` defaults to screen scale. Pin it to one so a 1,024 point
        // target is also at most 1,024 pixels, keeping each app-managed logo bounded.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let normalized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let data = normalized.jpegData(compressionQuality: 0.82) else { throw StoreError.invalidImage }
        return data
    }

    /// Renders exactly the square visible in the cropper. Offset is measured in viewport points;
    /// the same cover scale and zoom are used by the cropper's image view.
    func squarePhotoData(from source: Data, viewportSide: CGFloat, zoom: CGFloat, offset: CGSize) throws -> Data {
        guard let image = UIImage(data: source), viewportSide.isFinite, viewportSide > 0,
              zoom.isFinite, zoom >= 1, image.size.width > 0, image.size.height > 0 else {
            throw StoreError.invalidImage
        }
        let geometry = WorkoutLogoCropGeometry(
            sourceWidth: Double(image.size.width),
            sourceHeight: Double(image.size.height),
            viewportSide: Double(viewportSide),
            zoom: Double(zoom)
        )
        let origin = geometry.cropOrigin(offsetX: Double(offset.width), offsetY: Double(offset.height))
        let cropSide = CGFloat(geometry.cropSide)
        guard origin.x.isFinite, origin.y.isFinite, cropSide.isFinite, cropSide > 0 else {
            throw StoreError.invalidImage
        }
        let crop = CGRect(x: origin.x, y: origin.y, width: cropSide, height: cropSide)
        let outputSide = min(maxPixelDimension, cropSide)
        let outputSize = CGSize(width: outputSide, height: outputSide)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let output = renderer.image { _ in
            let ratio = outputSide / cropSide
            image.draw(in: CGRect(
                x: -crop.minX * ratio,
                y: -crop.minY * ratio,
                width: image.size.width * ratio,
                height: image.size.height * ratio
            ))
        }
        guard let data = output.jpegData(compressionQuality: 0.82) else { throw StoreError.invalidImage }
        return data
    }

    /// Writes a pending draft image only when its containing plan is being saved.
    /// Call `discardUncommittedPhoto(named:)` if persisting that returned logo fails.
    func materialize(_ draft: WorkoutLogoDraft) throws -> WorkoutLogo {
        guard let pendingPhotoData = draft.pendingPhotoData else { return draft.logo }
        try ensureDirectory()
        let filename = "\(UUID().uuidString.lowercased()).jpg"
        let destination = directoryURL.appendingPathComponent(filename, isDirectory: false)
        try pendingPhotoData.write(to: destination, options: .atomic)
        var logo = draft.logo
        logo.photoFilename = filename
        return logo
    }

    func image(for filename: String?) -> UIImage? {
        guard let filename, isSafeFilename(filename) else { return nil }
        let key = filename as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: directoryURL.appendingPathComponent(filename).path) else {
            return nil
        }
        let pixels = image.size.width * image.size.height * image.scale * image.scale
        imageCache.setObject(image, forKey: key, cost: Int(pixels * 4))
        return image
    }

    func discardUncommittedPhoto(named filename: String?) {
        guard let filename, isSafeFilename(filename) else { return }
        imageCache.removeObject(forKey: filename as NSString)
        try? fileManager.removeItem(at: directoryURL.appendingPathComponent(filename))
    }

    /// Deletes image files not referenced by saved plans or immutable history snapshots.
    func cleanup(retaining filenames: Set<String>) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        let retained = Set(filenames.filter(isSafeFilename))
        for file in files where isSafeFilename(file.lastPathComponent) && !retained.contains(file.lastPathComponent) {
            imageCache.removeObject(forKey: file.lastPathComponent as NSString)
            try? fileManager.removeItem(at: file)
        }
    }

    func retainedFilenames(in data: AppData) -> Set<String> {
        let live = data.plans.compactMap(\.logo.photoFilename)
        let snapshots = data.history.compactMap(\.planSnapshot?.logo.photoFilename)
        return Set((live + snapshots).filter(isSafeFilename))
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func isSafeFilename(_ filename: String) -> Bool {
        filename.range(of: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\.jpg$", options: .regularExpression) != nil
    }
}

/// Mutable editor state. Pending data remains memory-only until `materialize(_:)` is called on Save.
struct WorkoutLogoDraft: Equatable {
    var logo: WorkoutLogo
    var pendingPhotoData: Data?

    init(logo: WorkoutLogo) {
        self.logo = logo
        pendingPhotoData = nil
    }

    var hasPhoto: Bool { pendingPhotoData != nil || logo.photoFilename != nil }

    mutating func setPendingPhotoData(_ data: Data) {
        pendingPhotoData = data
    }

    mutating func removePhoto() {
        pendingPhotoData = nil
        logo.photoFilename = nil
    }

    mutating func reset() {
        logo = .default
        pendingPhotoData = nil
    }
}
