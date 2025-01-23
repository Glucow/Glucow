import SwiftUI
import Foundation

class UnitManager: ObservableObject {
    static let shared = UnitManager()

    @AppStorage("unitsIsMmol") private var unitsIsMmol: Bool = true

    var currentUnit: String {
        return unitsIsMmol ? "mmol/L" : "mg/dL"
    }

    func toggleUnit() {
        unitsIsMmol.toggle()
        UserDefaults.standard.set(unitsIsMmol, forKey: "unitsIsMmol") // Save the new state
        NotificationCenter.default.post(name: .unitDidChange, object: nil)
    }

    func setUnit(isMmol: Bool) {
        unitsIsMmol = isMmol
        NotificationCenter.default.post(name: .unitDidChange, object: nil)
    }

    func convertToCurrentUnit(valueInMgdl: Double) -> Double {
        // Convert from mg/dL to mmol/L if unitsIsMmol is true
        return unitsIsMmol ? valueInMgdl / 18.0 : valueInMgdl
    }

    func convertToBaseUnit(value: Double) -> Double {
        // Convert from mmol/L to mg/dL if unitsIsMmol is true
        return unitsIsMmol ? value * 18.0 : value
    }
}

extension Notification.Name {
    static let unitDidChange = Notification.Name("unitDidChange")
    
}
