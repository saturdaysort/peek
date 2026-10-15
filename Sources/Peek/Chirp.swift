import AppKit

/// A 120 ms two-note square-wave blip (B5 then E6), synthesized once as an 8-bit WAV.
enum Chirp {
    private static let sound = NSSound(data: wav())

    static func play() {
        sound?.stop()
        sound?.play()
    }

    private static func wav() -> Data {
        let rate = 22_050
        var samples: [UInt8] = []
        for (frequency, milliseconds) in [(987.77, 55), (1318.51, 65)] {
            let count = rate * milliseconds / 1000
            for i in 0..<count {
                let high = (Double(i) * frequency / Double(rate)).truncatingRemainder(dividingBy: 1) < 0.5
                let fade = 1 - Double(i) / Double(count) * 0.5
                samples.append(UInt8(128.0 + (high ? 1.0 : -1.0) * 28.0 * fade))
            }
        }
        var data = Data()
        func u32(_ v: Int) { withUnsafeBytes(of: UInt32(v).littleEndian) { data.append(contentsOf: $0) } }
        func u16(_ v: Int) { withUnsafeBytes(of: UInt16(v).littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); u32(36 + samples.count)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1); u32(rate); u32(rate); u16(1); u16(8)
        data.append(contentsOf: Array("data".utf8)); u32(samples.count)
        data.append(contentsOf: samples)
        return data
    }
}
