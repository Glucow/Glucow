import SwiftUI

enum AppFlowStage {
    case welcome
    case unitsChoice
    case rangeSetup
    case main
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var stage: AppFlowStage = .welcome
    @StateObject private var viewModel = MeasurementViewModel.shared
    @ObservedObject private var unitManager = UnitManager.shared

    @State private var veryLowRange: ClosedRange<Double> = 0.0...3.8
    @State private var lowRange: ClosedRange<Double>     = 3.9...4.9
    @State private var inRange: ClosedRange<Double>      = 5.0...8.5
    @State private var highRange: ClosedRange<Double>    = 8.6...13.9
    @State private var veryHighRange: ClosedRange<Double> = 14.0...27.0

    @AppStorage("enableTextReading") private var enableTextReading: Bool = true

    var body: some View {
        Group {
            switch stage {
            case .welcome:
                WelcomeView {
                    stage = .main
                }

            case .unitsChoice:
                UnitsChoiceView { isMmol in
                    unitManager.toggleUnit() // Use UnitManager to handle toggling
                    updateRangesForUnit(isMmol: isMmol)
                    stage = .rangeSetup
                }

            case .rangeSetup:
                RangeSetupView(
                    useMmol: unitManager.currentUnit == "mmol/L",
                    veryLowRange: $veryLowRange,
                    lowRange: $lowRange,
                    inRange: $inRange,
                    highRange: $highRange,
                    veryHighRange: $veryHighRange
                ) {
                    storePreferences()
                    stage = .main
                }

            case .main:
                MainMeasurementView(
                    veryLowRange: veryLowRange,
                    lowRange: lowRange,
                    inRange: inRange,
                    highRange: highRange,
                    veryHighRange: veryHighRange,
                    showTextReading: enableTextReading
                )
            }
        }
        .onAppear {
            let savedUnitIsMmol = UserDefaults.standard.bool(forKey: "unitsIsMmol")
            UnitManager.shared.setUnit(isMmol: savedUnitIsMmol)
            
            let token = UserDefaults.standard.string(forKey: "authToken")
            let userId = UserDefaults.standard.string(forKey: "userId")
            if token != nil, userId != nil {
                stage = .main
            }

            loadRangesFromPreferences()
            viewModel.loadMeasurements()
        }
        
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {
                UserDefaults.standard.set(UnitManager.shared.currentUnit == "mmol/L", forKey: "unitsIsMmol")
                viewModel.saveMeasurements()
            } else if newPhase == .active {
                viewModel.loadMeasurements() // Reload data when the app becomes active
            }
        }
    }


    private func clampToValidRange(_ range: ClosedRange<Double>, isMmol: Bool) -> ClosedRange<Double> {
        if isMmol {
            let lower = max(0.0, min(30.0, range.lowerBound))
            let upper = max(0.0, min(30.0, range.upperBound))
            return lower...upper
        } else {
            let lower = max(0.0, min(600.0, range.lowerBound))
            let upper = max(0.0, min(600.0, range.upperBound))
            return lower...upper
        }
    }

    private func updateRangesForUnit(isMmol: Bool) {
        if isMmol {
            veryLowRange = clampToValidRange(0.0...3.8, isMmol: true)
            lowRange = clampToValidRange(3.9...4.9, isMmol: true)
            inRange = clampToValidRange(5.0...8.5, isMmol: true)
            highRange = clampToValidRange(8.6...13.9, isMmol: true)
            veryHighRange = clampToValidRange(14.0...27.0, isMmol: true)
        } else {
            veryLowRange = clampToValidRange((0.0 * 18)...(3.8 * 18), isMmol: false)
            lowRange = clampToValidRange((3.9 * 18)...(4.9 * 18), isMmol: false)
            inRange = clampToValidRange((5.0 * 18)...(8.5 * 18), isMmol: false)
            highRange = clampToValidRange((8.6 * 18)...(13.9 * 18), isMmol: false)
            veryHighRange = clampToValidRange((14.0 * 18)...(27.0 * 18), isMmol: false)
        }
    }

    private func loadRangesFromPreferences() {
        if let arr = UserDefaults.standard.array(forKey: "veryLowRange") as? [Double], arr.count == 2 {
            self.veryLowRange = clampToValidRange(arr[0]...arr[1], isMmol: unitManager.currentUnit == "mmol/L")
        }
        if let arr = UserDefaults.standard.array(forKey: "lowRange") as? [Double], arr.count == 2 {
            self.lowRange = clampToValidRange(arr[0]...arr[1], isMmol: unitManager.currentUnit == "mmol/L")
        }
        if let arr = UserDefaults.standard.array(forKey: "inRange") as? [Double], arr.count == 2 {
            self.inRange = clampToValidRange(arr[0]...arr[1], isMmol: unitManager.currentUnit == "mmol/L")
        }
        if let arr = UserDefaults.standard.array(forKey: "highRange") as? [Double], arr.count == 2 {
            self.highRange = clampToValidRange(arr[0]...arr[1], isMmol: unitManager.currentUnit == "mmol/L")
        }
        if let arr = UserDefaults.standard.array(forKey: "veryHighRange") as? [Double], arr.count == 2 {
            self.veryHighRange = clampToValidRange(arr[0]...arr[1], isMmol: unitManager.currentUnit == "mmol/L")
        }
    }

    private func storePreferences() {
        UserDefaults.standard.set([veryLowRange.lowerBound, veryLowRange.upperBound], forKey: "veryLowRange")
        UserDefaults.standard.set([lowRange.lowerBound, lowRange.upperBound], forKey: "lowRange")
        UserDefaults.standard.set([inRange.lowerBound, inRange.upperBound], forKey: "inRange")
        UserDefaults.standard.set([highRange.lowerBound, highRange.upperBound], forKey: "highRange")
        UserDefaults.standard.set([veryHighRange.lowerBound, veryHighRange.upperBound], forKey: "veryHighRange")
    }
}
