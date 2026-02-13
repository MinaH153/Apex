import Foundation
import Supabase

// MARK: - Info.plist Configuration
//
// SUPABASE_URL and SUPABASE_ANON_KEY are read from Info.plist at runtime.
// This avoids hardcoding environment-specific values and allows different
// configurations per build scheme (e.g. Debug vs Release).
//
// ATS (App Transport Security) — Info.plist includes an NSExceptionDomains
// entry for "localhost" only (NSExceptionAllowsInsecureHTTPLoads = true,
// NSIncludesSubdomains = false). This permits HTTP connections to the local
// Supabase dev server. It does NOT use NSAllowsArbitraryLoads, so all
// non-localhost traffic still requires HTTPS.
//
// The localhost exception is safe to ship in Release builds because it only
// affects connections to 127.0.0.1/localhost, which are not reachable in
// production. Production SUPABASE_URL should always use https://.

@MainActor
final class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()

    let client: Supabase.SupabaseClient

    @Published var session: Session?

    private init() {
        // Reads Supabase config from Info.plist (see comment above)
        guard let info = Bundle.main.infoDictionary,
              let urlString = info["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              let anonKey = info["SUPABASE_ANON_KEY"] as? String
        else {
            fatalError("SUPABASE_URL and SUPABASE_ANON_KEY must be set in Info.plist")
        }

        client = Supabase.SupabaseClient(supabaseURL: url, supabaseKey: anonKey)

        // Listen for auth state changes
        Task {
            for await (event, session) in client.auth.authStateChanges {
                if event == .signedIn {
                    self.session = session
                } else if event == .signedOut {
                    self.session = nil
                }
            }
        }
    }

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(email: email, password: password)
        self.session = session
    }

    func signOut() async throws {
        try await client.auth.signOut()
        self.session = nil
    }
}
