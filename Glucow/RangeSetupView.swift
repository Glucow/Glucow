import SwiftUI

struct RangeSetupView: View {
    let useMmol: Bool

    @Binding var veryLowRange: ClosedRange<Double>
    @Binding var lowRange: ClosedRange<Double>
    @Binding var inRange: ClosedRange<Double>
    @Binding var highRange: ClosedRange<Double>
    @Binding var veryHighRange: ClosedRange<Double>

    let onComplete: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Very Low (Red)")) {
                    manualRow(title: "From", value: lowerBinding(for: $veryLowRange))
                    manualRow(title: "To",   value: upperBinding(for: $veryLowRange))
                }

                Section(header: Text("Low (Yellow)")) {
                    manualRow(title: "From", value: lowerBinding(for: $lowRange))
                    manualRow(title: "To",   value: upperBinding(for: $lowRange))
                }

                Section(header: Text("In Range (Green)")) {
                    manualRow(title: "From", value: lowerBinding(for: $inRange))
                    manualRow(title: "To",   value: upperBinding(for: $inRange))
                }

                Section(header: Text("High (Yellow)")) {
                    manualRow(title: "From", value: lowerBinding(for: $highRange))
                    manualRow(title: "To",   value: upperBinding(for: $highRange))
                }

                Section(header: Text("Very High (Red)")) {
                    manualRow(title: "From", value: lowerBinding(for: $veryHighRange))
                    manualRow(title: "To",   value: upperBinding(for: $veryHighRange))
                }

                Section {
                    Button("Done") {
                        onComplete()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Set Your Glucose Ranges")
        }
    }

    // A subview that shows label + text field
    @ViewBuilder
    private func manualRow(title: String, value: Binding<String>) -> some View {
        HStack {
            Text(title)
            TextField("", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)

            if useMmol {
                Text("mmol/L")
                    .foregroundColor(.secondary)
            } else {
                Text("mg/dL")
                    .foregroundColor(.secondary)
            }
        }
    }

    // Create a string binding for the lower bound
    private func lowerBinding(for range: Binding<ClosedRange<Double>>) -> Binding<String> {
        Binding<String>(
            get: {
                formatNumber(range.wrappedValue.lowerBound)
            },
            set: { newStr in
                if let newVal = Double(newStr) {
                    // keep newVal <= old upper bound
                    let oldUpper = range.wrappedValue.upperBound
                    if newVal > oldUpper {
                        range.wrappedValue = oldUpper...oldUpper
                    } else {
                        range.wrappedValue = newVal...oldUpper
                    }
                }
            }
        )
    }

    // Create a string binding for the upper bound
    private func upperBinding(for range: Binding<ClosedRange<Double>>) -> Binding<String> {
        Binding<String>(
            get: {
                formatNumber(range.wrappedValue.upperBound)
            },
            set: { newStr in
                if let newVal = Double(newStr) {
                    // keep newVal >= old lower bound
                    let oldLower = range.wrappedValue.lowerBound
                    if newVal < oldLower {
                        range.wrappedValue = oldLower...oldLower
                    } else {
                        range.wrappedValue = oldLower...newVal
                    }
                }
            }
        )
    }

    private func formatNumber(_ val: Double) -> String {
        if useMmol {
            return String(format: "%.1f", val)
        } else {
            return String(format: "%.0f", val)
        }
    }
}
