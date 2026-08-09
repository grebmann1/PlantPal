import Foundation
import Supabase

@MainActor
final class AppState: ObservableObject {
    @Published var session: Session?
    @Published private(set) var isGuest: Bool
    @Published var isReady = false

    private var authTask: Task<Void, Never>?

    init() {
        isGuest = UserDefaults.standard.bool(forKey: "pp.isGuest")
        isReady = isGuest
        authTask = Task { [weak self] in

            guard let self else { return }
            for await change in SupabaseManager.client.auth.authStateChanges {
                self.session = change.session
                self.isReady = true
            }
        }
    }

    deinit {
        authTask?.cancel()
    }

    var isSignedIn: Bool { session != nil || isGuest }
    var userId: UUID? { session?.user.id }
    var userEmail: String? { session?.user.email }

    /// Stable local identity used for guest sessions so garden data can be kept
    /// on-device (no Supabase auth token exists for guests, so cloud writes would
    /// fail RLS checks). Signed-in users always use their real Supabase user id.
    var guestUserId: UUID {
        if let stored = UserDefaults.standard.string(forKey: "pp.guestUserId"), let uuid = UUID(uuidString: stored) {
            return uuid
        }
        let new = UUID()
        UserDefaults.standard.set(new.uuidString, forKey: "pp.guestUserId")
        return new
    }

    /// The id to use for all garden data operations: the real account id when signed
    /// in, or a persisted local guest id otherwise. Use this instead of `userId`
    /// everywhere garden/scan/reminder data is read or written.
    var effectiveUserId: UUID? { session?.user.id ?? (isGuest ? guestUserId : nil) }

    func continueAsGuest() {
        UserDefaults.standard.set(true, forKey: "pp.isGuest")
        isGuest = true
        isReady = true
    }

    /// Clears the local guest flag after a real account session is established.
    func clearGuestMode() {
        UserDefaults.standard.removeObject(forKey: "pp.isGuest")
        isGuest = false
    }

    func signOut() async {
        if session != nil {
            try? await SupabaseManager.client.auth.signOut()
        }
        UserDefaults.standard.removeObject(forKey: "pp.isGuest")
        isGuest = false
    }
}
