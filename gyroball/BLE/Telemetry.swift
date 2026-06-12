import Foundation

struct Telemetry {
    var rpm: Double = 0
    var topSpeed: Double = 0
    var totalRevolutions: Double = 0
    var activeSeconds: TimeInterval = 0
    var isActive: Bool = false

    var averageRPM: Double {
        activeSeconds > 1 ? totalRevolutions / activeSeconds * 60 : 0
    }

    // FFF4 packet (8 bytes): 00 00 | period uint16 BE | 00 00 | flag, counter
    // The raw value is the rotation period in 4 MHz timer ticks, so speed is
    // its inverse: RPM = 40e6 / raw. Calibrated against the NSD app:
    // raw 23441 → 1694 RPM (+0.7%), raw 10213 → 3920 RPM (−0.1%).
    static let periodConstant = 40_000_000.0

    static func rpm(fromRaw raw: UInt16) -> Double? {
        // Below ~800 the implied speed exceeds 60k RPM — a glitch, not a reading.
        guard raw > 800 else { return nil }
        return Self.periodConstant / Double(raw)
    }

    static func decodeRPM(from data: Data) -> Double? {
        guard let raw = rawValue(from: data) else { return nil }
        return rpm(fromRaw: raw)
    }

    static func rawValue(from data: Data) -> UInt16? {
        guard data.count >= 4 else { return nil }
        return (UInt16(data[2]) << 8) | UInt16(data[3])
    }
}
