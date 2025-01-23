import SwiftUI

struct WelcomeView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoggingIn: Bool = false

    // Called when login succeeds
    let onLoginSuccess: () -> Void

    var body: some View {
        VStack {
            Spacer()

            // Title
            Text("Welcome to Glucow")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Spacer()

            // Login fields
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)

                // "Don't have an account?" under the password
                HStack {
                    Button("Don’t have an account?") {
                        // Link to your sign-up flow or Safari link
                    }
                    .foregroundColor(.blue)
                    Spacer()
                }

                if let msg = errorMessage {
                    Text(msg)
                        .foregroundColor(.red)
                        .font(.subheadline)
                }

                // Log In button with a loading indicator
                Button(action: attemptLogin) {
                    if isLoggingIn {
                        // Show a spinner or progress view
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(height: 20)
                    } else {
                        Text("Log In")
                            .font(.headline)
                    }
                }
                .disabled(isLoggingIn)
                .padding()
                .frame(maxWidth: .infinity)
                .background(isLoggingIn ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 40)
    }

    private func attemptLogin() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }

        isLoggingIn = true
        errorMessage = nil

        LibreLinkUpClient.shared.login(email: email, password: password) { result in
            DispatchQueue.main.async {
                self.isLoggingIn = false
                switch result {
                case .success:
                    HealthManager.shared.requestAuthorization { success, error in
                        if success {
                            onLoginSuccess()
                        } else if let error = error {
                            print("Authorization failed with error: \(error.localizedDescription)")
                            // Handle the error as needed
                        } else {
                            print("Authorization failed without an error")
                            // Handle the failure scenario without error details
                        }
                    }
                    onLoginSuccess()
                case .failure(let err):
                    errorMessage = "Login failed: \(err.localizedDescription)"
                }
            }
        }
    }
}
