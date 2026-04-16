import SwiftUI
import UIKit

struct EmailAuthView: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    enum Mode { case signIn, register }

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    enum Field { case firstName, lastName, email, password, confirmPassword }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.black, Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Fields card
                        VStack(spacing: 0) {
                            if mode == .register {
                                HStack(spacing: 12) {
                                    FloatingField(
                                        label: "First Name",
                                        text: $firstName,
                                        field: .firstName,
                                        focusedField: $focusedField
                                    )
                                    FloatingField(
                                        label: "Last Name",
                                        text: $lastName,
                                        field: .lastName,
                                        focusedField: $focusedField
                                    )
                                }
                                .transition(.asymmetric(
                                    insertion: .push(from: .top).combined(with: .opacity),
                                    removal: .push(from: .bottom).combined(with: .opacity)
                                ))

                                fieldDivider
                            }

                            FloatingField(
                                label: "Email",
                                text: $email,
                                field: .email,
                                focusedField: $focusedField,
                                keyboardType: .emailAddress
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                            fieldDivider

                            FloatingField(
                                label: "Password",
                                text: $password,
                                field: .password,
                                focusedField: $focusedField,
                                isSecure: true
                            )

                            if mode == .register {
                                fieldDivider

                                FloatingField(
                                    label: "Confirm Password",
                                    text: $confirmPassword,
                                    field: .confirmPassword,
                                    focusedField: $focusedField,
                                    isSecure: true
                                )
                                .transition(.asymmetric(
                                    insertion: .push(from: .bottom).combined(with: .opacity),
                                    removal: .push(from: .top).combined(with: .opacity)
                                ))
                            }
                        }
                        .background(Color(white: 0.13), in: RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal, 24)

                        // Password hint for register
                        if mode == .register {
                            Text("Password must be at least 6 characters")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.35))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 28)
                                .transition(.opacity)
                        }

                        // Error message
                        if let errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption)
                                Text(errorMessage)
                                    .font(.system(size: 14))
                            }
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 28)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Submit button
                        Button {
                            focusedField = nil
                            Task { await submit() }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, Color(red: 0, green: 0.6, blue: 0.4)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 56)
                                    .shadow(color: .green.opacity(isFormValid ? 0.35 : 0), radius: 12, y: 4)

                                if isLoading {
                                    ProgressView().tint(.white).scaleEffect(1.1)
                                } else {
                                    Text(mode == .signIn ? "Sign In" : "Create Account")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .disabled(isLoading || !isFormValid)
                        .animation(.easeInOut(duration: 0.2), value: isFormValid)

                        // Toggle mode
                        Button {
                            withAnimation(.spring(duration: 0.35)) {
                                errorMessage = nil
                                mode = mode == .signIn ? .register : .signIn
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(mode == .signIn ? "Don't have an account?" : "Already have an account?")
                                    .foregroundStyle(.white.opacity(0.45))
                                Text(mode == .signIn ? "Create one" : "Sign in")
                                    .foregroundStyle(.green)
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 15))
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 32)
                    .animation(.spring(duration: 0.35), value: mode)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Color(white: 0.18), in: Circle())
            }

            Spacer()

            Text(mode == .signIn ? "Welcome back" : "Create account")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .animation(.none, value: mode)

            Spacer()

            // Balance the X button
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var fieldDivider: some View {
        Rectangle()
            .fill(Color(white: 0.22))
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private var isFormValid: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let validEmail = trimmedEmail.contains("@") && trimmedEmail.contains(".")
        let validPassword = password.count >= 6
        if mode == .signIn {
            return validEmail && validPassword
        } else {
            return validEmail && validPassword && password == confirmPassword
        }
    }

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            if mode == .signIn {
                try await authService.signInWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } else {
                try await authService.registerWithEmail(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces)
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Floating label field

private struct FloatingField: View {
    let label: String
    @Binding var text: String
    let field: EmailAuthView.Field
    var focusedField: FocusState<EmailAuthView.Field?>.Binding
    var keyboardType: UIKeyboardType = .default
    var isSecure = false

    private var isFocused: Bool { focusedField.wrappedValue == field }
    private var isActive: Bool { isFocused || !text.isEmpty }

    var body: some View {
        ZStack(alignment: .leading) {
            // Floating label
            Text(label)
                .font(.system(size: isActive ? 11 : 16))
                .foregroundStyle(isFocused ? .green : .white.opacity(isActive ? 0.4 : 0.3))
                .offset(y: isActive ? -10 : 0)
                .animation(.spring(duration: 0.2), value: isActive)

            // Input
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboardType)
                }
            }
            .focused(focusedField, equals: field)
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .offset(y: isActive ? 8 : 0)
            .animation(.spring(duration: 0.2), value: isActive)
        }
        .frame(height: 64)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { focusedField.wrappedValue = field }
        .overlay(alignment: .bottom) {
            if isFocused {
                Rectangle()
                    .fill(Color.green.opacity(0.6))
                    .frame(height: 1.5)
                    .transition(.scale(scale: 0, anchor: .center).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.2), value: isFocused)
    }
}

#Preview {
    EmailAuthView()
        .environmentObject(AuthService())
}
