import SwiftUI

struct UnitsChoiceView: View {
    // The user’s selection
    @State private var selectedUnit: UnitChoice = .mgdl

    let onComplete: (Bool) -> Void

    var body: some View {
        VStack(spacing: 40) {
            Text("Please select your units")
                .font(.title2)
                .padding(.top, 60)

            HStack(spacing: 16) {
                unitButton(title: "mg/dL", choice: .mgdl)
                unitButton(title: "mmol/L", choice: .mmol)
            }

            Spacer()

            Button("Continue") {
                onComplete(selectedUnit == .mmol)
            }
            .font(.headline)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.bottom, 40)
        }
        .padding()
    }

    @ViewBuilder
    private func unitButton(title: String, choice: UnitChoice) -> some View {
        Button(action: {
            selectedUnit = choice
        }) {
            Text(title)
                .font(.headline)
                .padding()
                .frame(minWidth: 100)
                .background(selectedUnit == choice ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(selectedUnit == choice ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

enum UnitChoice {
    case mgdl
    case mmol
}
