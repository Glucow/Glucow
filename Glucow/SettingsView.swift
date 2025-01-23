import SwiftUI

struct SettingsView: View {
    @AppStorage("enableDarkMode") private var enableDarkMode: Bool = false
    @AppStorage("enableGraph") private var enableGraph: Bool = true
    @AppStorage("enableTextReading") private var enableTextReading: Bool = true
    @AppStorage("enableAppleHealth") private var enableAppleHealth: Bool = true
    @AppStorage("rangeVeryLowUpper") private var rangeVeryLowUpper: Double = 3.8
    @AppStorage("rangeLowUpper") private var rangeLowUpper: Double = 4.9
    @AppStorage("rangeInRangeUpper") private var rangeInRangeUpper: Double = 8.5
    @AppStorage("rangeHighUpper") private var rangeHighUpper: Double = 13.9
    @AppStorage("rangeVeryHighUpper") private var rangeVeryHighUpper: Double = 27.0

    struct BGButton: View {
        @ObservedObject private var unitManager = UnitManager.shared

        var body: some View {
            Button(action: {
                unitManager.toggleUnit()
            }) {
                HStack {
                    Text("Blood Glucose Units")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(unitManager.currentUnit)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    struct DSButton: View {
        var body: some View {
            Button(action: {
                //
            }) {
                HStack {
                    Text("Data Source")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("LibreLinkUp-API")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    struct SensorSNButton: View {
        @AppStorage("sensorSerialNumber") private var sensorSerialNumber: String = ""

        var body: some View {
            Button(action: {
                //
            }) {
                HStack {
                    Text("Sensor SN")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(sensorSerialNumber)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    struct GlucowVersionButton: View {
        var body: some View {
            Button(action: {
                //
            }) {
                HStack {
                    Text("Version")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    struct GlucowBuildButton: View {
        var body: some View {
            Button(action: {
                //
            }) {
                HStack {
                    Text("Build")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("1")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    struct GlucowLicenseButton: View {
        var body: some View {
            Button(action: {
                //
            }) {
                HStack {
                    Text("License")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("ⓘ")
                        .foregroundColor(.blue)
                }
            }
        }
    }

    struct SensorExpiryButton: View {
        @AppStorage("sensorExpiryText") private var sensorExpiryText: String = ""

        var body: some View {
            Button(action: {
                //
            }) {
                HStack {
                    Text("Sensor Expiry")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(sensorExpiryText)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    func openWikiURL() {
        if let url = URL(string: "https://www.apple.com") {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("URL was successfully opened.")
                } else {
                    print("Failed to open URL.")
                }
            }
        } else {
            print("Invalid URL.")
        }
    }

    func openLicenseURL() {
        if let url = URL(string: "https://www.gnu.org/licenses/gpl-3.0.en.html") {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("URL was successfully opened.")
                } else {
                    print("Failed to open URL.")
                }
            }
        } else {
            print("Invalid URL.")
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("📖 Help & FAQ")) {
                    Button("Open Wiki") {
                        openWikiURL()
                    }
                }
                Section(header: Text("🩸 Libre 3 Data")) {
                    BGButton()
                    DSButton()
                    Button("Username") {
                        //
                    }
                    Button("Password") {
                        //
                    }
                    SensorSNButton()
                    SensorExpiryButton()
                }

                Section(header: Text("📈 Main Screen")) {
                    Toggle("Enable Graph", isOn: $enableGraph)
                    Toggle("Enable Text Readings", isOn: $enableTextReading)
                    Toggle("Allow Landscape Mode", isOn: $enableDarkMode)
                    Toggle("Show Time when Locked", isOn: $enableDarkMode)
                    HStack {
                        Text("🔴 Urgent High Value")
                        TextField("", value: $rangeVeryHighUpper, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("🟡 High Value")
                        TextField("", value: $rangeHighUpper, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("🟢 Target Limit Value")
                        TextField("", value: $rangeInRangeUpper, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("🟡 Low Value")
                        TextField("", value: $rangeLowUpper, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("🔴 Very Low Value")
                        TextField("", value: $rangeVeryLowUpper, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }

                Section(header: Text("📊 Statistics")) {
                    Toggle("Show Statistics", isOn: $enableDarkMode)
                }

                Section(header: Text("⏰ Alarms")) {
                    Toggle("-", isOn: $enableDarkMode)
                    Toggle("-", isOn: $enableDarkMode)
                    Toggle("-", isOn: $enableDarkMode)
                    Toggle("-", isOn: $enableDarkMode)
                }

                Section(header: Text("❤️ Apple Health")) {
                    Toggle("Write Data to Apple Health", isOn: $enableAppleHealth)
                }

                Section(header: Text("ℹ️ About Glucow")) {
                    GlucowVersionButton()
                    GlucowBuildButton()
                    GlucowLicenseButton()
                }
            }
            .navigationTitle("Settings")
        }
    }
}
