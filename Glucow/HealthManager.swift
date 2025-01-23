// healthmanager.swift
//
// used to manage apple healthkit record from data

import HealthKit

class HealthManager {
    static let shared = HealthManager()
    private let healthStore = HKHealthStore()

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            completion(false, nil)
            return
        }
        healthStore.requestAuthorization(toShare: [glucoseType], read: [glucoseType]) { success, error in
            completion(success, error)
        }
    }

    func saveGlucoseSample(value: Double, date: Date) {
        guard let glucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else { return }

        // Determine the value to save in mg/dL
        let valueInMgdl: Double
        if UnitManager.shared.currentUnit == "mmol/L" {
            // Convert mmol/L to mg/dL for HealthKit
            valueInMgdl = value / 18.0
        } else {
            // Already in mg/dL, use value directly
            valueInMgdl = value
        }

        let unit = HKUnit(from: "mg/dL")
        let quantity = HKQuantity(unit: unit, doubleValue: valueInMgdl)

        let sample = HKQuantitySample(type: glucoseType, quantity: quantity,
                                      start: date, end: date)
        healthStore.save(sample) { success, error in
            if !success {
                print("Failed to save glucose to HealthKit: \(error?.localizedDescription ?? "unknown error")")
            } else {
                print("Glucose sample saved successfully in mg/dL.")
            }
        }
    }


}
