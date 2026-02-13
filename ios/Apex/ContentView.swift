import SwiftUI

struct ContentView: View {
    @StateObject private var supabase = SupabaseManager.shared

    var body: some View {
        TabView {
            FilesView()
                .tabItem {
                    Label("Files", systemImage: "doc")
                }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sign Out") {
                    Task {
                        try? await supabase.signOut()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
