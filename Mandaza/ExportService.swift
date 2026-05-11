import UIKit
import Photos

/// Saves a UIImage to the user's Photo Library, requesting permission only
/// when needed. Async, throws on denial / failure.
enum ExportError: Error, LocalizedError {
    case noPermission
    case savedFailed

    var errorDescription: String? {
        switch self {
        case .noPermission: return "Photo Library access was denied."
        case .savedFailed:  return "Could not save the image."
        }
    }
}

@MainActor
enum ExportService {
    static func saveToPhotos(_ image: UIImage) async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let granted: Bool
        switch status {
        case .authorized, .limited:
            granted = true
        case .notDetermined:
            granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly) == .authorized
        default:
            granted = false
        }
        guard granted else { throw ExportError.noPermission }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { ok, err in
                if ok { cont.resume() }
                else { cont.resume(throwing: err ?? ExportError.savedFailed) }
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// A handful of common iPhone wallpaper resolutions.
    /// Falls back to "current screen × 3" if you want something custom.
    static let presets: [(label: String, size: CGSize)] = [
        ("iPhone (Pro)",         CGSize(width: 1290, height: 2796)),
        ("iPhone (Standard)",    CGSize(width: 1170, height: 2532)),
        ("iPad",                 CGSize(width: 2048, height: 2732)),
        ("Square 4K",            CGSize(width: 3840, height: 3840))
    ]
}
