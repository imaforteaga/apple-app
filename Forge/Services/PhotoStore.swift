import SwiftUI
import UIKit
import ImageIO

/// Persistent, private photo storage inside Application Support (never the temporary
/// cache, so photos survive restarts). Photos are only ever shared when the user taps export.
enum PhotoStore {
    enum PhotoError: LocalizedError {
        case encodeFailed
        var errorDescription: String? { "The photo could not be saved. Please try again." }
    }

    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ProgressPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 120
        return c
    }()

    static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    /// Saves the image as JPEG (orientation baked in, long edge ≤ 2400 px). Returns the file name.
    static func save(_ image: UIImage) throws -> String {
        let prepared = normalize(image, maxDimension: 2400)
        guard let data = prepared.jpegData(compressionQuality: 0.88) else { throw PhotoError.encodeFailed }
        let name = UUID().uuidString + ".jpg"
        try data.write(to: url(for: name), options: [.atomic, .completeFileProtectionUnlessOpen])
        return name
    }

    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
        // Drop cached thumbnails for this file
        for px in [200, 400, 600, 900, 1400, 2400] {
            cache.removeObject(forKey: "\(fileName)@\(px)" as NSString)
        }
    }

    static func exists(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName).path)
    }

    private static func normalize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        let scale = longEdge > maxDimension ? maxDimension / longEdge : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Down-sampled image (cheap on memory for grids).
    static func image(fileName: String, maxPixel: Int) -> UIImage? {
        let key = "\(fileName)@\(maxPixel)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let fileURL = url(for: fileName)
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let img = UIImage(cgImage: cg)
        cache.setObject(img, forKey: key)
        return img
    }

    static func imageAsync(fileName: String, maxPixel: Int) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            image(fileName: fileName, maxPixel: maxPixel)
        }.value
    }

    /// Copies a photo to a temporary, nicely-named file for the share sheet.
    static func exportURL(for photo: ProgressPhoto) -> URL? {
        let src = url(for: photo.fileName)
        guard FileManager.default.fileExists(atPath: src.path) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let name = "Forge-\(f.string(from: photo.date))-\(photo.angle.rawValue)-\(photo.id.uuidString.prefix(4)).jpg"
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            return dest
        } catch {
            return nil
        }
    }
}

/// Displays a stored progress photo. Apply `.frame` / `.aspectRatio` at the call site.
struct StoredImage: View {
    let fileName: String
    var maxPixel: Int = 600
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else if failed {
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ProgressView()
                }
            }
            .background(Theme.cardAlt)
            .clipped()
            .task(id: fileName) {
                image = await PhotoStore.imageAsync(fileName: fileName, maxPixel: maxPixel)
                failed = image == nil
            }
    }
}

// MARK: - Camera

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
