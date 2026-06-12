import CoreBluetooth
import Combine

final class BLEManager: NSObject, ObservableObject {

    static let serviceUUID   = CBUUID(string: "FFF0")
    static let telemetryUUID = CBUUID(string: "FFF4")
    static let extraService  = CBUUID(string: "FEBA")
    static let deviceName    = "NSD Workout"

    @Published var telemetry   = Telemetry()
    @Published var isConnected = false
    @Published var rpmHistory: [Double] = []
    @Published var lastRawValue: UInt16 = 0

    /// Fires once per decoded telemetry packet with the current RPM.
    let packetTick = PassthroughSubject<Double, Never>()

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var lastUpdateTime: Date?
    private var inactivityTimer: Timer?
    private let historyLimit = 60

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func resetSession() {
        telemetry = Telemetry()
        rpmHistory = []
        lastUpdateTime = nil
        inactivityTimer?.invalidate()
    }

    private func scan() {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: [Self.serviceUUID])
    }

    private func handleRPM(_ rpm: Double, raw: UInt16) {
        let now = Date()
        lastRawValue = raw

        // Only accumulate over continuous packet streams; gaps mean the ball
        // was disconnected or idle and shouldn't count as workout time.
        if let prev = lastUpdateTime {
            let dt = now.timeIntervalSince(prev)
            if dt < 2.0 {
                telemetry.totalRevolutions += ((telemetry.rpm + rpm) / 2.0 / 60.0) * dt
                telemetry.activeSeconds += dt
            }
        }
        lastUpdateTime = now

        telemetry.rpm      = rpm
        telemetry.topSpeed = max(telemetry.topSpeed, rpm)
        telemetry.isActive = true
        packetTick.send(rpm)

        rpmHistory.append(rpm)
        if rpmHistory.count > historyLimit { rpmHistory.removeFirst() }

        inactivityTimer?.invalidate()
        inactivityTimer = .scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.telemetry.isActive = false
        }
    }

    // MARK: - Raw packet log (for protocol calibration)

    private static let logURL: URL = {
        let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Gyroball", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("raw.log")
    }()

    private static let logTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private func logPacket(uuid: CBUUID, data: Data) {
        let hex  = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        let line = "\(Self.logTimeFormatter.string(from: Date())) \(uuid.uuidString) \(hex)\n"
        guard let bytes = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: Self.logURL) {
            handle.seekToEndOfFile()
            handle.write(bytes)
            try? handle.close()
        } else {
            try? bytes.write(to: Self.logURL)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { scan() }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi: NSNumber) {
        guard peripheral.name == Self.deviceName else { return }
        self.peripheral = peripheral
        central.stopScan()
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID, Self.extraService])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        isConnected = false
        telemetry.isActive = false
        self.peripheral = nil
        scan()
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        self.peripheral = nil
        scan()
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { svc in
            // FEBA carries unknown session data; subscribe to everything and log
            // it so the protocol can be decoded from real captures later.
            let wanted: [CBUUID]? = svc.uuid == Self.serviceUUID ? [Self.telemetryUUID] : nil
            peripheral.discoverCharacteristics(wanted, for: svc)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        service.characteristics?.forEach { char in
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }
        logPacket(uuid: characteristic.uuid, data: data)

        guard characteristic.uuid == Self.telemetryUUID,
              let rpm = Telemetry.decodeRPM(from: data),
              let raw = Telemetry.rawValue(from: data) else { return }
        handleRPM(rpm, raw: raw)
    }
}
