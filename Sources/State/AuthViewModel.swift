import Foundation
import AuthenticationServices
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode { case signIn, signUp }

    @Published var mode: Mode = .signIn
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    var isValid: Bool {
        email.contains("@") && password.count >= 6
    }

    func submit() async {
        guard isValid else {
            errorMessage = String(localized: "Enter a valid email and a password with at least 6 characters.")
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch mode {
            case .signIn:
                try await SupabaseManager.client.auth.signIn(email: email, password: password)
            case .signUp:
                try await SupabaseManager.client.auth.signUp(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        switch result {
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = String(localized: "Apple sign-in did not return a valid credential.")
                return
            }
            isLoading = true
            defer { isLoading = false }
            do {
                try await SupabaseManager.client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken)
                )
            } catch {
                errorMessage = String(localized: "Apple sign-in isn't fully enabled yet on the backend. Please use email instead, or try again shortly.")
            }
        }
    }
}
