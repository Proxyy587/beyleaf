import AppKit
import SwiftUI

/// beepo is Belay's logo (brand/README.md): the character that routes what you ask. This file draws it where an image is
/// needed instead of a view: the menu bar and the app icon. The notch's own mark is `BrandSlot`.
@MainActor
enum BeepoMark {
    /// The menu bar item: beepo as a template image, so macOS draws it in the menu bar's own colour (black or white), like every
    /// other menu bar icon. The body is solid and the eyes are cut out of it, so it reads at 18 pt in both appearances.
    static func menuBarImage(size: CGFloat = 18) -> NSImage {
        // Draw the body black with white eyes, then turn "how white" into "how see-through": template images use alpha only.
        let renderer = ImageRenderer(content: BuddyView(id: .beepo, style: .smooth, mood: .idle, size: size, eyeColor: .white, tint: .black))
        renderer.scale = 3
        guard let cg = renderer.cgImage, let mask = alphaMask(from: cg) else { return NSImage(size: NSSize(width: size, height: size)) }
        let image = NSImage(cgImage: mask, size: NSSize(width: size, height: size))
        image.isTemplate = true
        image.accessibilityDescription = "Belay"
        return image
    }

    /// Black where the picture was black, see-through where it was white, partly between. Pure pixel arithmetic.
    private static func alphaMask(from cg: CGImage) -> CGImage? {
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        for i in stride(from: 0, to: px.count, by: 4) {
            let a = Double(px[i + 3]) / 255
            guard a > 0 else { continue }
            // Premultiplied colour over alpha is the real colour; its brightness is how much of the eye is here.
            let light = min(1, (Double(px[i]) + Double(px[i + 1]) + Double(px[i + 2])) / 3 / 255 / a)
            px[i] = 0; px[i + 1] = 0; px[i + 2] = 0
            px[i + 3] = UInt8((a * (1 - light) * 255).rounded())
        }
        return ctx.makeImage()
    }

    /// The app icon artwork at 1024: a near-black rounded square with beepo on it. One flat colour behind, no gradients or
    /// shadows (brand/README.md); the 100 pt margin is macOS's icon grid.
    static func appIconPNG() -> Data? {
        let art = ZStack {
            RoundedRectangle(cornerRadius: 185, style: .continuous).fill(Color(red: 0.043, green: 0.043, blue: 0.047))
                .frame(width: 824, height: 824)
            BuddyView(id: .beepo, style: .smooth, mood: .idle, size: 540)
                .offset(y: 14)
        }
        .frame(width: 1024, height: 1024)
        let renderer = ImageRenderer(content: art)
        renderer.scale = 1
        guard let cg = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }

    /// `--render-icon <file.png>`: writes the app icon and quits. `scripts/make-icon.sh` turns it into AppIcon.icns.
    static func renderIconIfAsked() {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "--render-icon"), a.indices.contains(i + 1) else { return }
        guard let data = appIconPNG() else { FileHandle.standardError.write(Data("icon render failed\n".utf8)); exit(1) }
        do { try data.write(to: URL(fileURLWithPath: a[i + 1])) } catch { FileHandle.standardError.write(Data("\(error)\n".utf8)); exit(1) }
        exit(0)
    }
}
