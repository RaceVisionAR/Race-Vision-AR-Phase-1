import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(white: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, Color(red: 0, green: 0.6, blue: 0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .green.opacity(0.3), radius: 15)

                    Text("RaceVisionAR")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Detect runners. See their story.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                VStack(spacing: 20) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .transition(.opacity)
                    }

                    ZStack {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = authService.prepareNonce()
                        } onCompletion: { result in
                            Task {
                                do {
                                    errorMessage = nil
                                    isLoading = true
                                    try await authService.handleSignInWithApple(result)
                                    isLoading = false
                                } catch {
                                    isLoading = false
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 27))
                        .padding(.horizontal, 40)
                        .opacity(isLoading ? 0 : 1)
                        .disabled(isLoading)

                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}
