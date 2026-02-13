import SwiftUI

@main
struct ApexApp: App {
    @StateObject private var supabase = SupabaseManager.shared

    var body: some Scene {
        WindowGroup {
            if supabase.session != nil {
                ContentView()
            } else {
                AuthView()
            }
        }
    }
}
