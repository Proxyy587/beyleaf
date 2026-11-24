import AudioToolbox
import CoreAudio
import Foundation
import os

/// Live band levels and beat pulses from the music player's own audio, for the notch's music bars (ADR 0017).
///
/// A Core Audio process tap (macOS 14.2+) on the player's processes only (Music or Spotify, matched by bundle ID), read
/// through a private aggregate device. Samples go straight into `BeatAnalyzer` in memory: nothing is recorded, written
/// to disk or sent anywhere, and no other app is heard.
///
/// It runs only while asked to (`NotchController` asks while music plays and the music wing is on screen) and stops
/// otherwise. If capture is refused or delivers only silence, `state` becomes `.unavailable` and the wing shows a
/// static glyph until the next track.
@MainActor
final class MusicBeat: ObservableObject {
    enum State: Equatable { case off, listening, unavailable }

    static let bands = BeatAnalyzer.edges.count - 1
    @Published private(set) var levels: [Float] = Array(repeating: 0, count: bands)
    @Published private(set) var pulse: Float = 0
    @Published private(set) var state: State = .off

    /// A `TapEngine` (typed `AnyObject` because the class needs macOS 14.2 and the app supports 14.0).
    private var engine: AnyObject?
    private var bundleID: String?
    private let log = Logger(subsystem: "app.belay.mac", category: "beat")

    /// Start or stop listening to the player with this bundle ID (nil stops).
    func listen(to bundleID: String?) {
        guard bundleID != self.bundleID || (bundleID != nil && engine == nil && state != .unavailable) else { return }
        stop()
        self.bundleID = bundleID
        guard let bundleID, state != .unavailable else { return }
        guard #available(macOS 14.2, *) else { state = .unavailable; return }
        do {
            let engine = try TapEngine(bundlePrefix: bundleID) { [weak self] levels, pulse in
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.publish(levels, pulse) } }
            } onSilence: { [weak self] in
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.giveUp("only silence for 3 s (permission denied?)") } }
            }
            self.engine = engine
            state = .listening
            log.notice("tap started for \(bundleID, privacy: .public)")
            // No buffers at all within 3 s means capture isn't running (refused, or no audio path): fall back.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self, weak engine] in
                guard let self, let engine, self.engine === engine, engine.buffersReceived == 0 else { return }
                self.giveUp("no audio buffers in 3 s")
            }
        } catch {
            giveUp("\(error)")
        }
    }

    /// A new track: try again after a failure (the user may have granted permission since).
    func retry() {
        guard state == .unavailable else { return }
        state = .off
        let id = bundleID; bundleID = nil
        listen(to: id)
    }

    private func stop() {
        if let engine {
            var summary = ""
            if #available(macOS 14.2, *) { summary = (engine as? TapEngine)?.stop() ?? "" }
            self.engine = nil
            log.notice("tap stopped: \(summary, privacy: .public)")
        }
        if state == .listening { state = .off }
        bundleID = nil
        if levels.contains(where: { $0 > 0 }) { levels = Array(repeating: 0, count: Self.bands) }
        pulse = 0
    }

    private func giveUp(_ why: String) {
        let id = bundleID
        stop()
        bundleID = id
        state = .unavailable
        log.notice("tap unavailable: \(why, privacy: .public)")
    }

    private func publish(_ levels: [Float], _ pulse: Float) {
        guard engine != nil else { return }
        self.levels = levels
        self.pulse = pulse
    }
}

/// The Core Audio side: tap → private aggregate device → IOProc → analyser. Lives on its own serial queue.
@available(macOS 14.2, *)
private final class TapEngine: @unchecked Sendable {
    struct Failure: Error, CustomStringConvertible { let description: String }

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "app.belay.beat", qos: .userInitiated)
    // Touched only on `queue`.
    private var analyzer: BeatAnalyzer!
    private var mono = [Float](repeating: 0, count: 8192)
    private var lastPublish: UInt64 = 0
    private var silentFrames = 0
    private var gaveUp = false
    private var callbacks = 0

    init(bundlePrefix: String, onFrame: @escaping @Sendable ([Float], Float) -> Void, onSilence: @escaping @Sendable () -> Void) throws {
        let processes = Self.processObjects(bundlePrefix: bundlePrefix)
        guard !processes.isEmpty else { throw Failure(description: "no audio process for \(bundlePrefix)") }

        let desc = CATapDescription(stereoMixdownOfProcesses: processes)
        desc.name = "Belay beat"
        desc.uuid = UUID()
        desc.isPrivate = true
        desc.muteBehavior = .unmuted
        var err = AudioHardwareCreateProcessTap(desc, &tapID)
        guard err == noErr else { throw Failure(description: "create tap: \(err)") }

        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var addr = Self.address(kAudioTapPropertyFormat)
        err = AudioObjectGetPropertyData(tapID, &addr, 0, nil, &size, &format)
        guard err == noErr, format.mFormatID == kAudioFormatLinearPCM, format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              format.mBitsPerChannel == 32 else { teardown(); throw Failure(description: "tap format: \(err)") }
        analyzer = BeatAnalyzer(sampleRate: format.mSampleRate)
        let channels = Int(max(1, format.mChannelsPerFrame))
        let interleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0

        guard let outputUID = Self.defaultOutputUID() else { teardown(); throw Failure(description: "no output device") }
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Belay beat",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: desc.uuid.uuidString]],
        ]
        err = AudioHardwareCreateAggregateDevice(description as CFDictionary, &deviceID)
        guard err == noErr else { teardown(); throw Failure(description: "create aggregate: \(err)") }

        err = AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, queue) { [weak self] _, input, _, _, _ in
            self?.consume(input, channels: channels, interleaved: interleaved, onFrame: onFrame, onSilence: onSilence)
        }
        guard err == noErr, let procID else { teardown(); throw Failure(description: "io proc: \(err)") }
        err = AudioDeviceStart(deviceID, procID)
        guard err == noErr else { teardown(); throw Failure(description: "start: \(err)") }
    }

    /// Stops capture; returns a one-line summary for the log (counts only, never audio).
    var buffersReceived: Int { queue.sync { callbacks } }

    func stop() -> String {
        teardown()
        return queue.sync { "\(analyzer?.frames ?? 0) analyses, \(callbacks) buffers, \(silentFrames) trailing silent samples" }
    }

    private func teardown() {
        if let procID {
            AudioDeviceStop(deviceID, procID)
            AudioDeviceDestroyIOProcID(deviceID, procID)
            self.procID = nil
        }
        if deviceID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(deviceID); deviceID = AudioObjectID(kAudioObjectUnknown) }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID); tapID = AudioObjectID(kAudioObjectUnknown) }
    }

    /// On `queue`: mix to mono, analyse, publish at most 30 times a second. Samples are never kept.
    private func consume(_ input: UnsafePointer<AudioBufferList>, channels: Int, interleaved: Bool,
                         onFrame: @Sendable ([Float], Float) -> Void, onSilence: @Sendable () -> Void) {
        callbacks += 1
        let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let first = list.first, let base = first.mData else { return }
        let frameCount: Int
        var allZero = true
        if interleaved || list.count == 1 {
            let ch = interleaved ? channels : 1
            frameCount = min(mono.count, Int(first.mDataByteSize) / (4 * ch))
            let p = base.assumingMemoryBound(to: Float.self)
            for f in 0..<frameCount {
                var sum: Float = 0
                for c in 0..<ch { sum += p[f * ch + c] }
                mono[f] = sum / Float(ch)
                if mono[f] != 0 { allZero = false }
            }
        } else {
            frameCount = min(mono.count, Int(first.mDataByteSize) / 4)
            for f in 0..<frameCount { mono[f] = 0 }
            for buffer in list {
                guard let d = buffer.mData else { continue }
                let p = d.assumingMemoryBound(to: Float.self)
                for f in 0..<frameCount { mono[f] += p[f] / Float(list.count) }
            }
            allZero = !mono[0..<frameCount].contains { $0 != 0 }
        }
        mono.withUnsafeBufferPointer { analyzer.process(UnsafeBufferPointer(rebasing: $0[0..<frameCount])) }

        // A denied capture delivers digital silence; real music is never exactly zero for 3 s while "playing".
        silentFrames = allZero ? silentFrames + frameCount : 0
        if !gaveUp, Double(silentFrames) > 3 * analyzer.sampleRate { gaveUp = true; onSilence() }

        let now = DispatchTime.now().uptimeNanoseconds
        if now - lastPublish >= 33_000_000 {
            lastPublish = now
            onFrame(analyzer.levels, analyzer.pulse)
        }
    }

    // MARK: Core Audio helpers

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    /// The audio process objects whose bundle ID starts with the player's (Spotify plays through helper processes).
    private static func processObjects(bundlePrefix: String) -> [AudioObjectID] {
        var addr = address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter { string($0, kAudioProcessPropertyBundleID)?.hasPrefix(bundlePrefix) == true }
    }

    private static func defaultOutputUID() -> String? {
        var addr = address(kAudioHardwarePropertyDefaultSystemOutputDevice)
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device) == noErr else { return nil }
        return string(device, kAudioDevicePropertyDeviceUID)
    }

    private static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}
