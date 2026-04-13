import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var errorMessage: String?
    @State private var isLoadingApple = false
    @State private var isLoadingGoogle = false
    @State private var showEmailAuth = false

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

                VStack(spacing: 14) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .transition(.opacity)
                    }

                    // Sign in with Apple
                    ZStack {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = authService.prepareNonce()
                        } onCompletion: { result in
                            Task {
                                do {
                                    errorMessage = nil
                                    isLoadingApple = true
                                    try await authService.handleSignInWithApple(result)
                                    isLoadingApple = false
                                } catch {
                                    isLoadingApple = false
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 27))
                        .padding(.horizontal, 40)
                        .opacity(isLoadingApple ? 0 : 1)
                        .disabled(isLoadingApple || isLoadingGoogle)

                        if isLoadingApple {
                            ProgressView().tint(.white).scaleEffect(1.2)
                        }
                    }

                    // Sign in with Google
                    ZStack {
                        Button {
                            Task {
                                do {
                                    errorMessage = nil
                                    isLoadingGoogle = true
                                    try await authService.signInWithGoogle()
                                    isLoadingGoogle = false
                                } catch {
                                    isLoadingGoogle = false
                                    errorMessage = error.localizedDescription
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image("google_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("Sign in with Google")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(.black.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 27))
                            .padding(.horizontal, 40)
                        }
                        .opacity(isLoadingGoogle ? 0 : 1)
                        .disabled(isLoadingApple || isLoadingGoogle)

                        if isLoadingGoogle {
                            ProgressView().tint(.white).scaleEffect(1.2)
                        }
                    }

                    // Divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(height: 1)
                            .padding(.leading, 40)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(height: 1)
                            .padding(.trailing, 40)
                    }

                    // Continue with Email
                    Button {
                        showEmailAuth = true
                    } label: {
                        Text("Continue with Email")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .overlay(
                                RoundedRectangle(cornerRadius: 27)
                                    .stroke(.white.opacity(0.35), lineWidth: 1.5)
                            )
                            .padding(.horizontal, 40)
                    }
                    .disabled(isLoadingApple || isLoadingGoogle)
                }
                .padding(.bottom, 60)
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView()
                .environmentObject(authService)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService())
}
