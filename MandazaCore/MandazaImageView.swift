import SwiftUI

/// Renders a `MandazaSnapshot` to a still `Image` at the given size. Used by
/// the widget extension (no animation budget) and by the app for thumbnail
/// previews in the Favorites grid.
public struct MandazaImageView: View {
    let snapshot: MandazaSnapshot
    let size: CGSize
    let scale: CGFloat

    public init(snapshot: MandazaSnapshot,
                size: CGSize,
                scale: CGFloat = 3) {
        self.snapshot = snapshot
        self.size = size
        self.scale = scale
    }

    public var body: some View {
        let pixels = CGSize(width: max(1, size.width * scale),
                            height: max(1, size.height * scale))
        if let image = MandazaEngine.renderImage(seed: snapshot.seed,
                                                 paletteId: snapshot.paletteId,
                                                 config: snapshot.config,
                                                 size: pixels) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            Color.black.frame(width: size.width, height: size.height)
        }
    }
}
