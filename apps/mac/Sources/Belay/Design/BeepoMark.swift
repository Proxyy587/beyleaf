import AppKit
import SwiftUI

/// beepo is Belay's logo (brand/README.md): the character that routes what you ask. This file draws it where an image is
/// needed instead of a view: the menu bar and the app icon. The notch's own mark is `BrandSlot`.
@MainActor
enum BeepoMark {
    /// The menu bar item: beepo in its own colour (a template image can't keep the eyes), 18 pt, crisp at 2×.
    static func menuBarImage(size: CGFloat = 18) -> NSImage {
        let renderer = ImageRenderer(content: BuddyView(id: .beepo, style: .smooth, mood: .idle, size: size))
        renderer.scale = 3
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
        image.size = NSSize(width: size, height: size)
        image.accessibilityDescription = "Belay"
        return image
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
