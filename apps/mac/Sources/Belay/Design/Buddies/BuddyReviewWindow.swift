#if DEBUG
import AppKit
import SwiftUI

/// Debug only (`scripts/run.sh --buddies [mood]`): every buddy in both styles at 16, 32, 64 and 128 pt, plus beepo at
/// 256 pt, on the notch's black. For checking the art in the real renderer, and its sharpness at every size.
/// `mood` (idle, blink, lookLeft, lookRight, hover, sleep, happy) holds one mood on all of them.
/// `--buddies-cycle` instead plays a blink, a look and a happy hop on all of them every 0.5 s, to measure the cost
/// of motion with `top` (docs/performance.md). Shipping code never loops.
@MainActor
enum BuddyReviewWindow {
    private static var window: NSWindow?

    static func showIfRequested() {
        let args = CommandLine.arguments
        let cycle = args.contains("--buddies-cycle")
        guard let i = args.firstIndex(of: "--buddies") ?? args.firstIndex(of: "--buddies-cycle") else { return }
        let mood = args.indices.contains(i + 1) ? BuddyMood(rawValue: args[i + 1]) ?? .idle : .idle
        let animator = BuddyAnimator()
        animator.set(mood)
        if cycle {
            var step = 0
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                MainActor.assumeIsolated {
                    switch step % 4 {
                    case 0: animator.blink()
                    case 1: animator.set(.lookLeft)
                    case 2: animator.set(.lookRight)
                    default: animator.cheer()
                    }
                    step += 1
                }
            }
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 900), styleMask: [.titled, .closable],
                         backing: .buffered, defer: false)
        w.title = "Buddies"
        w.isReleasedWhenClosed = false
        w.contentView = args.contains("--one")
            ? NSHostingView(rootView: AnyView(One(buddy: animator)))
            : NSHostingView(rootView: AnyView(Sheet(buddy: animator)))
        w.center()
        w.makeKeyAndOrderFront(nil)
        window = w
    }

    /// One buddy per style at 64 pt, for a per-buddy CPU reading.
    private struct One: View {
        let buddy: BuddyAnimator
        var body: some View {
            HStack(spacing: 24) {
                BuddyView(id: .beepo, mood: buddy.mood, size: 64, hop: buddy.hop)
                BuddyView(id: .beepo, style: .pixel, mood: buddy.mood, size: 64, hop: buddy.hop)
            }
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black)
        }
    }

    private struct Sheet: View {
        let buddy: BuddyAnimator
        var body: some View {
            let mood = buddy.mood, hop = buddy.hop
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(BuddyID.allCases) { id in
                        HStack(alignment: .bottom, spacing: 14) {
                            Text(id.rawValue).font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                                .frame(width: 56, alignment: .leading)
                            ForEach(BuddyStyle.allCases, id: \.self) { style in
                                ForEach([16, 32, 64] as [CGFloat], id: \.self) { s in
                                    BuddyView(id: id, style: style, mood: mood, size: s, hop: hop)
                                }
                            }
                        }
                    }
                }
                VStack(spacing: 16) {
                    HStack(alignment: .bottom, spacing: 16) {
                        BuddyView(id: .beepo, style: .smooth, mood: mood, size: 128, hop: hop)
                        BuddyView(id: .beepo, style: .pixel, mood: mood, size: 128, hop: hop)
                    }
                    HStack(alignment: .bottom, spacing: 16) {
                        BuddyView(id: .beepo, style: .smooth, mood: mood, size: 256, hop: hop)
                        BuddyView(id: .otto, style: .pixel, mood: mood, size: 256, hop: hop)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.black)
        }
    }
}
#endif
