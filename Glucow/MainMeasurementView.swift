import SwiftUI

struct MainMeasurementView: View {
    let veryLowRange: ClosedRange<Double>
    let lowRange: ClosedRange<Double>
    let inRange: ClosedRange<Double>
    let highRange: ClosedRange<Double>
    let veryHighRange: ClosedRange<Double>
    let showTextReading: Bool

    @StateObject private var viewModel = MeasurementViewModel.shared
    @ObservedObject private var unitManager = UnitManager.shared

    @AppStorage("enableGraph") private var enableGraph: Bool = true
    @State private var showSettingsSheet = false
    @AppStorage("textVal") private var textVal: String = "green"
    @AppStorage("sensorExpiryText") private var sensorExpiryText: String = "Loading..."

    var displayedMeasurementValue: String {
        guard let valStr = viewModel.measurementValue, let readingValue = Double(valStr) else {
            return "..."
        }
        // Use UnitManager to convert the value dynamically
        let convertedValue = unitManager.convertToCurrentUnit(valueInMgdl: readingValue)
        return String(format: unitManager.currentUnit == "mmol/L" ? "%.1f" : "%.0f", convertedValue)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Top row
            HStack {
                VStack(alignment: .leading) {
                    Text("Latest Reading:")
                    Text(viewModel.readingTimeDisplay)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Next update:")
                    Text(viewModel.nextUpdateCountdown ?? "...")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            .padding([.top, .horizontal])

            // Settings gear
            HStack {
                Spacer()
                Button(action: {
                    showSettingsSheet = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .padding(.trailing, 15)
                }
            }

            Spacer()

            if viewModel.isSensorInGracePeriod {
                Text("Sensor ready in:")
                    .font(.title)
                if let countdown = viewModel.sensorReadyCountdown {
                    Text(countdown)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.orange)
                } else {
                    Text("Calculating...")
                        .font(.title2)
                }
            } else {
                if let valStr = viewModel.measurementValue,
                   let readingVal = Double(valStr) {
                    if showTextReading, let textReading = viewModel.textReadingString {
                        Text(textReading)
                            .font(.headline)
                            .foregroundColor(
                                textVal == "rangegreen" ? .green :
                                textVal == "rangered" ? .red :
                                textVal == "rangeyellow" ? .yellow : .blue
                            )
                    }
                    // Big reading + arrow
                    ZStack(alignment: .bottomLeading) {
                        HStack(spacing: 8) {
                            Text(displayedMeasurementValue)
                                .font(.system(size: 50, weight: .bold))
                            if let arrow = viewModel.sinceLastTrendArrow {
                                Text(arrow)
                                    .font(.system(size: 50, weight: .bold))
                            }
                        }
                        .background(
                            GeometryReader { geo in
                                getColorBar(for: readingVal)
                                    .frame(width: geo.size.width, height: 6)
                                    .cornerRadius(3)
                                    .offset(x: 0, y: geo.size.height + 2)
                            }
                        )
                    }
                } else {
                    Text("Loading...")
                        .font(.title)
                }
            }

            Spacer()

            // The chart
            if enableGraph {
                if unitManager.currentUnit == "mmol/L" {
                    GlucoseChartMMOLView(
                        dataPoints: viewModel.chartDataPoints,
                        veryLowRange: veryLowRange,
                        lowRange: lowRange,
                        inRange: inRange,
                        highRange: highRange,
                        veryHighRange: veryHighRange
                    )
                } else {
                    GlucoseChartMGDLView(
                        dataPoints: viewModel.chartDataPoints,
                        veryLowRange: veryLowRange,
                        lowRange: lowRange,
                        inRange: inRange,
                        highRange: highRange,
                        veryHighRange: veryHighRange,
                        useMmol: false
                    )
                }
            }

            Spacer()

            // Patient info
            VStack(spacing: 2) {
                Text("Patient: \(viewModel.patientInfo)")
                    .font(.headline)
                if let sensorType = viewModel.sensorType {
                    Text("Sensor type: \(sensorType)")
                        .font(.subheadline)
                }
                Text(sensorTimeLeftText())
                    .font(.subheadline)
            }
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
        .onAppear {
            viewModel.start(
                showTextReadings: showTextReading,
                userRanges: UserRanges(
                    veryLow: veryLowRange,
                    low: lowRange,
                    inRange: inRange,
                    high: highRange,
                    veryHigh: veryHighRange
                )
            )
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private func getColorBar(for readingVal: Double) -> some View {
        if veryLowRange.contains(readingVal) {
            return Color.red
        } else if lowRange.contains(readingVal) {
            return Color.yellow
        } else if inRange.contains(readingVal) {
            return Color.green
        } else if highRange.contains(readingVal) {
            return Color.yellow
        } else if veryHighRange.contains(readingVal) {
            return Color.red
        } else {
            return Color.gray
        }
    }

    private func sensorTimeLeftText() -> String {
        guard let activation = viewModel.sensorUnixActivation else {
            sensorExpiryText = "Sensor info not found (maybe not activated)"
            return sensorExpiryText
        }
        let lifespanSec = 337.0 * 3600.0
        let nowSec = Date().timeIntervalSince1970
        let expirySec = Double(activation) + lifespanSec
        let diff = expirySec - nowSec
        if diff <= 0 {
            sensorExpiryText = "Sensor expired, please activate a new one."
            return sensorExpiryText
        }
        let diffDays = Int(diff / 86400)
        let remainderSec = diff.truncatingRemainder(dividingBy: 86400)
        let diffHours = Int(remainderSec / 3600)
        sensorExpiryText = "\(diffDays) days, \(diffHours) hours"
        return sensorExpiryText
    }
}
