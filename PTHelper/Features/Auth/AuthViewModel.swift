import Foundation
import Supabase

@Observable
@MainActor
final class AuthViewModel {
    var session: Session?
    var profile: UserProfile?
    var isLoading = false
    var errorMessage: String?

    private(set) var isGuest: Bool

    var isAuthorized: Bool { isSignedIn || isGuest }
    var isSignedIn: Bool { session != nil }
    var currentUser: User? { session?.user }

    init() {
        isGuest = UserDefaults.standard.bool(forKey: "pthelper.isGuest")
        Task { await listenForAuthChanges() }
    }

    // MARK: - Auth state

    private func listenForAuthChanges() async {
        for await (_, session) in supabase.auth.authStateChanges {
            self.session = session
            if let session {
                clearGuestMode()
                await loadProfile(userId: session.user.id)
            } else {
                profile = nil
            }
        }
    }

    // MARK: - Guest

    func continueAsGuest() {
        isGuest = true
        UserDefaults.standard.set(true, forKey: "pthelper.isGuest")
    }

    func clearGuestMode() {
        isGuest = false
        UserDefaults.standard.removeObject(forKey: "pthelper.isGuest")
    }

    // MARK: - Sign in / up / out

    func signIn(email: String, password: String) async {
        await run {
            try await supabase.auth.signIn(email: email, password: password)
        }
    }

    func signUp(email: String, password: String) async {
        await run {
            try await supabase.auth.signUp(email: email, password: password)
        }
    }

    func signOut() async {
        clearGuestMode()
        await run { try await supabase.auth.signOut() }
    }

    func resetPassword(email: String) async {
        await run { try await supabase.auth.resetPasswordForEmail(email) }
    }

    // MARK: - Profile

    func loadProfile(userId: UUID) async {
        do {
            profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
        } catch {
            profile = UserProfile(id: userId)
        }
    }

    func saveProfile(fullName: String, username: String) async {
        guard let userId = currentUser?.id else { return }
        await run {
            try await supabase
                .from("profiles")
                .upsert([
                    "id": userId.uuidString,
                    "full_name": fullName,
                    "username": username.isEmpty ? nil : username,
                ])
                .execute()
            await loadProfile(userId: userId)
        }
    }

    // MARK: - Helpers

    private func run(_ block: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do {
            try await block()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
