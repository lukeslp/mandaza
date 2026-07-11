/*
 File Purpose: Parse Mandaza's public URL routes without trusting external text.
 Primary Components: MandazaDeepLink.
 Inputs / Outputs: Accepts a URL and returns a canonical UUID seed only for the
 documented mandaza://seed/<UUID> route.
 */

import Foundation

public enum MandazaDeepLink {
    public static func seed(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "mandaza",
              components.host == "seed",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.percentEncodedQuery == nil,
              components.fragment == nil else {
            return nil
        }

        let path = components.percentEncodedPath
        guard path.hasPrefix("/"), !path.dropFirst().contains("/") else { return nil }
        let candidate = String(path.dropFirst())
        guard let uuid = UUID(uuidString: candidate) else { return nil }
        return uuid.uuidString
    }

    public static func url(for snapshot: MandazaSnapshot) -> URL? {
        guard let data = try? JSONEncoder().encode(snapshot) else { return nil }
        var components = URLComponents()
        components.scheme = "mandaza"
        components.host = "snapshot"
        components.queryItems = [
            URLQueryItem(name: "data", value: data.base64EncodedString())
        ]
        return components.url
    }

    public static func snapshot(from url: URL) -> MandazaSnapshot? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "mandaza",
              components.host == "snapshot",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.percentEncodedPath.isEmpty,
              components.fragment == nil,
              let items = components.queryItems,
              items.count == 1,
              items[0].name == "data",
              let encoded = items[0].value,
              encoded.count <= 8_192,
              let data = Data(base64Encoded: encoded) else {
            return nil
        }
        guard let snapshot = try? JSONDecoder().decode(MandazaSnapshot.self, from: data),
              !snapshot.seed.isEmpty,
              snapshot.seed.count <= 512,
              snapshot.config.isValidForExternalRendering,
              Palette.all.contains(where: { $0.id == snapshot.paletteId }) ||
                ["riso", "arctic"].contains(snapshot.paletteId) else {
            return nil
        }
        return snapshot
    }
}
