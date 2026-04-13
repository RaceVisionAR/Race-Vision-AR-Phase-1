import AuthenticationServices
import Combine
import CryptoKit
import FirebaseFirestore
import FirebaseAuth
import Foundation
import GoogleSignIn
import UIKit

@MainActor
final class AuthService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var authError: Error?

    var isSignedIn: Bool { user != nil }

    private var currentNonce: String?

    init() {
        user = Auth.auth().currentUser
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }

    // Called by SignInWithAppleButton request closure — stores nonce and returns sha256 hash.
    func prepareNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // Called by SignInWithAppleButton completion closure.
    func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .success(let authorization):
            guard
                let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = appleCredential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                throw AuthError.invalidCredential
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: appleCredential.fullName
            )

            let authResult = try await Auth.auth().signIn(with: firebaseCredential)
            
            // Extract profile info
            let email = appleCredential.email
            let firstName = appleCredential.fullName?.givenName
            let lastName = appleCredential.fullName?.familyName
            
            // Save to Firestore
            await saveUserProfile(uid: authResult.user.uid, email: email, firstName: firstName, lastName: lastName)
            
            user = authResult.user

        case .failure(let error as ASAuthorizationError) where error.code == .canceled:
            // User dismissed the sheet — not an error
            break

        case .failure(let error):
            throw error
        }
    }

    func signInWithGoogle() async throws {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            throw AuthError.noRootViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidCredential
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        let profile = result.user.profile
        await saveUserProfile(
            uid: authResult.user.uid,
            email: profile?.email,
            firstName: profile?.givenName,
            lastName: profile?.familyName
        )
        user = authResult.user
    }

    func signInWithEmail(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        user = result.user
    }

    func registerWithEmail(email: String, password: String, firstName: String, lastName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        await saveUserProfile(
            uid: result.user.uid,
            email: email,
            firstName: firstName.isEmpty ? nil : firstName,
            lastName: lastName.isEmpty ? nil : lastName
        )
        user = result.user
    }

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        self.user = nil
        self.authError = nil
    }

    // MARK: - Private helpers

    private func saveUserProfile(uid: String, email: String?, firstName: String?, lastName: String?) async {
        let db = Firestore.firestore()
        var userData: [String: Any] = [
            "uid": uid,
            "lastLogin": FieldValue.serverTimestamp()
        ]
        
        if let email { userData["email"] = email }
        if let firstName { userData["firstName"] = firstName }
        if let lastName { userData["lastName"] = lastName }
        
        do {
            // Use setData with merge: true to avoid overwriting existing data if they sign in again
            // (Note: Apple only sends email/name on FIRST sign-in, so we won't get them on subsequent logins)
            try await db.collection("users").document(uid).setData(userData, merge: true)
            print(" [AuthService] User profile saved to Firestore")
        } catch {
            print(" [AuthService] Error saving user profile: \(error.localizedDescription)")
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    enum AuthError: LocalizedError {
        case invalidCredential
        case noRootViewController

        var errorDescription: String? {
            switch self {
            case .invalidCredential: return "Sign in failed. Please try again."
            case .noRootViewController: return "Unable to present sign-in. Please try again."
            }
        }
    }
}
