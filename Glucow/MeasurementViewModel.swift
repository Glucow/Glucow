// MeasurementViewModel.swift
import SwiftUI
import HealthKit
import UserNotifications
import Foundation

struct UserRanges {
    let veryLow: ClosedRange<Double>
    let low: ClosedRange<Double>
    let inRange: ClosedRange<Double>
    let high: ClosedRange<Double>
    let veryHigh: ClosedRange<Double>
}

class MeasurementViewModel: ObservableObject {
    @Published var patientInfo: String = ""
    @Published var measurementValue: String?
    @Published var sinceLastTrendArrow: String?
    @Published var measurementColorName: String = "gray"
    @Published var readingTimeDisplay: String = "..."
    @Published var nextUpdateCountdown: String?
    @Published var sensorUnixActivation: Int?
    @Published var sensorType: String?
    @Published var isSensorInGracePeriod: Bool = false
    @Published var sensorReadyCountdown: String?
    @Published var textReadingString: String?
    @ObservedObject private var unitManager = UnitManager.shared
    static let shared = MeasurementViewModel()

    @AppStorage("textVal") private var textVal: String = "green"
    @AppStorage("sensorSerialNumber") private var sensorSerialNumber: String = ""
    @AppStorage("sensorExpiryText") private var sensorExpiryText: String = ""
    @AppStorage("enableAppleHealth") private var enableAppleHealth: Bool = true

    private var timer: Timer?
    private var nextUpdateTimer: Timer?
    private var nextUpdateDate: Date?
    private var storedMeasurements: [GlucoseReading] = []
    
    private var dataFileURL: URL {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return documentsDirectory.appendingPathComponent("glucose_readings.json")
    }

    @Published var refreshTrigger = false

    var chartDataPoints: [(date: Date, value: Double)] {
        storedMeasurements.map { reading in
            let convertedValue = UnitManager.shared.convertToCurrentUnit(valueInMgdl: reading.mgdlValue)
            return (reading.timestamp, convertedValue)
        }
    }
    
    private var showTextReading: Bool = false
    private var userRanges: UserRanges? = nil

    struct GlucoseReading: Codable {
        let timestamp: Date
        let mgdlValue: Double
    }
    

    func start(showTextReadings: Bool, userRanges: UserRanges) {
        self.showTextReading = showTextReadings
        self.userRanges = userRanges

        requestNotificationPermission()
        loadMeasurements()
        fetchData()
        scheduleNextMinute()
        updateCountdownLoop()
    }
    
    func saveMeasurements() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(storedMeasurements)
            try data.write(to: dataFileURL)
            UserDefaults.standard.set(UnitManager.shared.currentUnit, forKey: "measurementUnit")
            print("Measurements saved successfully.")
        } catch {
            print("Failed to save measurements: \(error)")
        }
    }

    
    func loadMeasurements() {
        do {
            let data = try Data(contentsOf: dataFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            storedMeasurements = try decoder.decode([GlucoseReading].self, from: data)
            
            // Handle unit conversion if necessary
            let savedUnit = UserDefaults.standard.string(forKey: "measurementUnit") ?? "mmol/L"
            if savedUnit != UnitManager.shared.currentUnit {
                storedMeasurements = storedMeasurements.map { reading in
                    if UnitManager.shared.currentUnit == "mmol/L" {
                        return GlucoseReading(timestamp: reading.timestamp, mgdlValue: reading.mgdlValue / 18.0)
                    } else {
                        return GlucoseReading(timestamp: reading.timestamp, mgdlValue: reading.mgdlValue * 18.0)
                    }
                }
                print("Measurements loaded and converted to unit: \(UnitManager.shared.currentUnit).")
            } else {
                print("Measurements loaded successfully.")
            }
        } catch {
            print("No saved measurements found or failed to load: \(error)")
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        nextUpdateTimer?.invalidate()
        nextUpdateTimer = nil
    }

    private func scheduleNextMinute() {
        let now = Date()
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        if let baseDate = Calendar.current.date(from: comps) {
            let nextMin = baseDate.addingTimeInterval(60)
            let interval = nextMin.timeIntervalSinceNow
            self.nextUpdateDate = nextMin
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.fetchData()
                self?.scheduleNextMinute()
            }
        }
    }

    private func updateCountdownLoop() {
        nextUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let next = self.nextUpdateDate else {
                DispatchQueue.main.async {
                    self.nextUpdateCountdown = nil
                }
                return
            }
            let diff = Int(next.timeIntervalSinceNow)
            DispatchQueue.main.async {
                self.nextUpdateCountdown = (diff <= 0) ? "0s" : "\(diff)s"
            }

            // Grace
            if self.isSensorInGracePeriod, let activationUnix = self.sensorUnixActivation {
                let graceEndSec = Double(activationUnix) + 3600
                let nowSec = Date().timeIntervalSince1970
                let remains = graceEndSec - nowSec
                if remains <= 0 {
                    DispatchQueue.main.async {
                        self.isSensorInGracePeriod = false
                        self.sensorReadyCountdown = nil
                        self.fetchData()
                    }
                } else {
                    let minLeft = Int(remains / 60)
                    let secLeft = Int(remains.truncatingRemainder(dividingBy: 60))
                    DispatchQueue.main.async {
                        self.sensorReadyCountdown = "\(minLeft)m \(secLeft)s"
                    }
                }
            }
        }
    }

    func fetchData() {
        guard
            let token = UserDefaults.standard.string(forKey: "authToken"),
            let userId = UserDefaults.standard.string(forKey: "userId"),
            let accountIdHash = UserDefaults.standard.string(forKey: "accountIdHash")
                
        else {
            return
        }
        fetchPatientInfoAndMeasurement(token: token, userId: userId, accountIdHash: accountIdHash)
    }

    private func fetchPatientInfoAndMeasurement(token: String,
                                                userId: String,
                                                accountIdHash: String) {
        let url = URL(string: "https://api.libreview.io/llu/connections")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(accountIdHash, forHTTPHeaderField: "Account-Id")
        req.setValue(userId, forHTTPHeaderField: "patientid")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        req.setValue("no-cache", forHTTPHeaderField: "cache-control")
        req.setValue("Keep-Alive", forHTTPHeaderField: "connection")
        req.setValue("llu.android", forHTTPHeaderField: "product")
        req.setValue("4.12", forHTTPHeaderField: "version")
        req.setValue("Mozilla/5.0 (Windows NT 10.0; rv:129.0) Gecko/20100101 Firefox/129.0",
                     forHTTPHeaderField: "user-agent")

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error {
                print("Connections error: \(error)")
                return
            }
            guard let data = data else { return }

            guard
                let dict = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                let status = dict["status"] as? Int, status == 0
            else {
                print("Connections: unexpected response or status != 0")
                return
            }

            if let dataArr = dict["data"] as? [[String:Any]],
               let firstConn = dataArr.first {
                let patientId = firstConn["patientId"] as? String ?? ""
                let firstName = firstConn["firstName"] as? String ?? ""
                let lastName = firstConn["lastName"] as? String ?? ""
                let sensor = firstConn["sensor"] as? [String:Any]

                DispatchQueue.main.async {
                    self.patientInfo = "\(firstName) \(lastName)"
                }

                if let activationUnix = sensor?["a"] as? Int {
                    DispatchQueue.main.async {
                        self.sensorUnixActivation = activationUnix
                        if let pt = sensor?["pt"] as? Int {
                            self.sensorType = {
                                switch pt {
                                case 4: return "Freestyle Libre 3"
                                case 1: return "Freestyle Libre 2"
                                case 0: return "Freestyle Libre 1"
                                default: return "Unknown"
                                }
                            }()
                        }
                        
                        if let serial = sensor?["serialNumber"] as? String {
                            self.sensorSerialNumber = serial
                        }
                        
                        let nowSec = Date().timeIntervalSince1970
                        let graceEndSec = Double(activationUnix) + 3600
                        self.isSensorInGracePeriod = (nowSec < graceEndSec)
                    }
                }

                self.fetchMeasurementForPatient(token: token,
                                                userId: userId,
                                                accountIdHash: accountIdHash,
                                                patientId: patientId)
            }
        }.resume()
    }

    private func fetchMeasurementForPatient(token: String,
                                            userId: String,
                                            accountIdHash: String,
                                            patientId: String) {
        let url = URL(string: "https://api.libreview.io/llu/connections/\(patientId)/graph")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(accountIdHash, forHTTPHeaderField: "Account-Id")
        req.setValue(userId, forHTTPHeaderField: "patientid")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("gzip", forHTTPHeaderField: "accept-encoding")
        req.setValue("no-cache", forHTTPHeaderField: "cache-control")
        req.setValue("Keep-Alive", forHTTPHeaderField: "connection")
        req.setValue("llu.android", forHTTPHeaderField: "product")
        req.setValue("4.12", forHTTPHeaderField: "version")
        req.setValue("Mozilla/5.0 (Windows NT 10.0; rv:129.0) Gecko/20100101 Firefox/129.0",
                     forHTTPHeaderField: "user-agent")

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error {
                print("Fetch measurement error: \(error)")
                return
            }
            guard let data = data else { return }
            guard
                let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let status = dict["status"] as? Int, status == 0
            else {
                print("Graph: unexpected response or status != 0")
                return
            }

            if let dataDict = dict["data"] as? [String: Any],
               let connDict = dataDict["connection"] as? [String: Any],
               let latest = connDict["glucoseMeasurement"] as? [String: Any] {

                let rawTs = latest["Timestamp"] as? String ?? ""
                let parsedDate = self.parseLibreTimestamp(rawTs)
                let mgdlVal = latest["ValueInMgPerDl"] as? Double ?? 0.0

                // Arrow + delta
                let (arrowEmoji, deltaVal) = self.computeDeltaArrow(newValueMgdl: mgdlVal, newTimestamp: parsedDate)
                self.storedMeasurements.append(GlucoseReading(timestamp: parsedDate, mgdlValue: mgdlVal))
                let userDefinedText = self.generateTextReading(mgdlValue: mgdlVal, arrowEmoji: arrowEmoji)
                self.sendLocalNotification(newValMgdl: mgdlVal, arrow: arrowEmoji, diff: deltaVal)
                
                if self.enableAppleHealth {
                    self.logToHealthKit(value: mgdlVal)
                } else { }

                DispatchQueue.main.async {
                    self.readingTimeDisplay = DateFormatter.localizedString(
                        from: parsedDate,
                        dateStyle: .none,
                        timeStyle: .medium
                    )

                    // Convert the measurement value for display using UnitManager
                    self.measurementValue = String(format: UnitManager.shared.currentUnit == "mmol/L" ? "%.1f" : "%.0f", mgdlVal)
                    self.sinceLastTrendArrow = arrowEmoji

                    if self.showTextReading {
                        self.textReadingString = userDefinedText
                    } else {
                        self.textReadingString = nil
                    }
                }
            }
        }.resume()
    }


    private func formatMmolValue(_ mgdlVal: Double) -> Double {
        let raw = mgdlVal / 18.0
        return (raw * 10).rounded() / 10
    }

    private func parseLibreTimestamp(_ ts: String) -> Date {
        let parts = ts.split(separator: " ")
        guard parts.count >= 3 else { return Date() }
        let df = DateFormatter()
        df.dateFormat = "M/d/yyyy h:mm:ss a"
        return df.date(from: "\(parts[0]) \(parts[1]) \(parts[2])") ?? Date()
    }

    private func computeDeltaArrow(newValueMgdl: Double, newTimestamp: Date) -> (String, Double) {
        guard let last = storedMeasurements.last else {
            return ("❓", 0.0)
        }
        let diffMinutes = newTimestamp.timeIntervalSince(last.timestamp) / 60.0
        if diffMinutes > 24 { return ("❓", 0.0) }
        let delta = newValueMgdl - last.mgdlValue
        let arrowNum = arrowNumFromDelta(delta)
        let arrowEmoji = arrowToEmoji(arrowNum)
        return (arrowEmoji, delta)
    }

    private func arrowNumFromDelta(_ diff: Double) -> Int {
        if abs(diff) < 0.1 { return 3 }    // stable
        if diff > 5 { return 5 }           // up
        if diff > 0 { return 4 }           // slight up
        if diff < -5 { return 1 }          // down
        if diff < 0 { return 2 }           // slight down
        return 3
    }

    private func arrowToEmoji(_ num: Int) -> String {
        switch num {
        case 1: return "⬇️"
        case 2: return "↘️"
        case 3: return "➡️"
        case 4: return "↗️"
        case 5: return "⬆️"
        default: return "❓"
        }
    }
    
    private func changeTextVal() {
            if textVal == "green" {
                textVal = "red"
            } else {
                textVal = "green"
            }
        }
    
    class TextValModel: ObservableObject {
        @Published var textVal: String = "green" // Initial value
    }

    private func generateTextReading(mgdlValue: Double, arrowEmoji: String) -> String {
        guard let r = userRanges else { return "Glucose in range" }
        
        let reading = UnitManager.shared.currentUnit == "mmol/L"
                ? UnitManager.shared.convertToCurrentUnit(valueInMgdl: mgdlValue)
                : round(UnitManager.shared.convertToCurrentUnit(valueInMgdl: mgdlValue))
        
        let isDown = (arrowEmoji == "⬇️" || arrowEmoji == "↘️")
        let isUp   = (arrowEmoji == "⬆️" || arrowEmoji == "↗️")

        print(reading)
        switch reading {
        case r.veryLow:
            textVal = "rangered"
            return isDown ? "Glucose going very low ⚠️" : "Glucose very low ⚠️"
        case r.low:
            textVal = "rangered"
            return isDown ? "Glucose going low ⚠️" : "Glucose low ⚠️"
        case r.inRange:
            textVal = "rangegreen"
            return "Glucose in range"
        case r.high:
            textVal = "rangeyellow"
            return isUp ? "Glucose going high ⚠️" : "Glucose high ⚠️"
        case r.veryHigh:
            textVal = "rangered"
            return isUp ? "Glucose going very high ⚠️" : "Glucose very high ⚠️"
        default:
            textVal = "rangeblue"
            return "Glucose out of range ⚠️"
        }
    }
    

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
            if let err = err {
                print("Notification permission error: \(err)")
            }
        }
    }

    private func logToHealthKit(value: Double) {
        // Convert the value to mg/dL if necessary
        let convertedValue = UnitManager.shared.convertToBaseUnit(value: value)
        
        DispatchQueue.global(qos: .background).async {
            // Save the converted value to HealthKit
            
            HealthManager.shared.saveGlucoseSample(value: convertedValue, date: Date())
            
            DispatchQueue.main.async {
                // Perform any UI updates or publish changes here
                print("Glucose value logged to HealthKit successfully")
            }
        }
    }

    private func sendLocalNotification(newValMgdl: Double, arrow: String, diff: Double) {
        let content = UNMutableNotificationContent()
        let convertedValue = UnitManager.shared.convertToCurrentUnit(valueInMgdl: newValMgdl)
        content.title = String(format: "%.1f %@ %@", convertedValue, UnitManager.shared.currentUnit, arrow)
        content.subtitle = String(format: "%+.1f", UnitManager.shared.convertToCurrentUnit(valueInMgdl: diff))
        content.sound = .default

        let req = UNNotificationRequest(identifier: "GlucowReadingNotification", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    
    
}
