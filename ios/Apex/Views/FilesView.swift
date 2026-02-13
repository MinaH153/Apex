import SwiftUI
import Supabase

struct FilesView: View {
    @StateObject private var supabase = SupabaseManager.shared

    @State private var files: [FileItem] = []
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var realtimeChannel: RealtimeChannelV2?
    @State private var loadFailed = false

    // Upload state
    @State private var isUploading = false
    @State private var uploadingFilename: String?
    @State private var showUploadSuccess = false
    @State private var failedUploadURL: URL?
    @State private var showUploadError = false
    @State private var uploadErrorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && files.isEmpty {
                    ProgressView("Loading files...")
                } else if loadFailed && files.isEmpty {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage ?? "Something went wrong.")
                    } actions: {
                        Button("Retry") {
                            Task { await loadFiles() }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if files.isEmpty {
                    ContentUnavailableView(
                        "No Files",
                        systemImage: "doc",
                        description: Text("Tap + to upload a file.")
                    )
                } else {
                    List {
                        ForEach(files) { file in
                            fileRow(file)
                        }
                        .onDelete(perform: deleteFiles)
                    }
                }
            }
            .navigationTitle("Files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isImporting = true }) {
                        Image(systemName: "plus")
                    }
                    .disabled(isUploading)
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .refreshable {
                await loadFiles()
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil && !loadFailed },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
                Button("Retry") {
                    Task { await loadFiles() }
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                await loadFiles()
                await subscribeToRealtime()
            }
            .onDisappear {
                Task {
                    await unsubscribeFromRealtime()
                }
            }
            .overlay {
                if isUploading {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Uploading \(uploadingFilename ?? "file")...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .overlay {
                if showUploadSuccess {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("Uploaded")
                            .font(.subheadline.bold())
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity)
                }
            }
            .alert("Upload Failed", isPresented: $showUploadError) {
                Button("Retry") {
                    if let url = failedUploadURL {
                        Task { await uploadFile(url: url) }
                    }
                }
                Button("Cancel", role: .cancel) {
                    failedUploadURL = nil
                }
            } message: {
                Text(uploadErrorMessage ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - File Row

    private func fileRow(_ file: FileItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(file.name)
                .font(.body)
                .lineLimit(1)
            HStack {
                if let size = file.size {
                    Text(formatFileSize(size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(file.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Load Files

    private func loadFiles() async {
        guard let userId = supabase.session?.user.id else {
            errorMessage = "Session expired. Please sign in again."
            loadFailed = true
            return
        }
        isLoading = true
        loadFailed = false
        do {
            let items: [FileItem] = try await supabase.client
                .from("files")
                .select()
                .eq("owner_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            files = items
        } catch {
            errorMessage = error.localizedDescription
            loadFailed = true
        }
        isLoading = false
    }

    // MARK: - Upload

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await uploadFile(url: url) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func uploadFile(url: URL) async {
        guard let userId = supabase.session?.user.id else {
            uploadErrorMessage = "Session expired. Please sign in again."
            showUploadError = true
            return
        }

        let filename = url.lastPathComponent
        isUploading = true
        uploadingFilename = filename
        failedUploadURL = url

        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let storagePath = "\(userId.uuidString)/\(filename)"

            // Upload to storage
            try await supabase.client.storage
                .from("files")
                .upload(storagePath, data: data)

            // Insert metadata row
            let row: [String: AnyJSON] = [
                "owner_id": .string(userId.uuidString),
                "name": .string(filename),
                "path": .string(storagePath),
                "size": .integer(data.count),
                "mime_type": .string(mimeType(for: filename)),
            ]
            try await supabase.client
                .from("files")
                .insert(row)
                .execute()

            isUploading = false
            failedUploadURL = nil

            // Show brief success feedback
            withAnimation { showUploadSuccess = true }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { showUploadSuccess = false }

            // Reload unless realtime picks it up
            await loadFiles()
        } catch {
            isUploading = false
            uploadErrorMessage = friendlyUploadError(error)
            showUploadError = true
        }
    }

    private func friendlyUploadError(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()
        if description.contains("duplicate") || description.contains("already exists") {
            return "A file with this name already exists. Please rename it and try again."
        }
        if description.contains("too large") || description.contains("payload") || description.contains("413") {
            return "The file is too large to upload."
        }
        if description.contains("timed out") || description.contains("timeout") {
            return "The upload timed out. Check your connection and try again."
        }
        if description.contains("network") || description.contains("offline") || description.contains("not connected") {
            return "Network error. Check your connection and try again."
        }
        return error.localizedDescription
    }

    // MARK: - Delete

    private func deleteFiles(at offsets: IndexSet) {
        let toDelete = offsets.map { files[$0] }
        Task {
            for file in toDelete {
                do {
                    // Remove from storage
                    try await supabase.client.storage
                        .from("files")
                        .remove(paths: [file.path])

                    // Remove metadata row
                    try await supabase.client
                        .from("files")
                        .delete()
                        .eq("id", value: file.id.uuidString)
                        .execute()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            await loadFiles()
        }
    }

    // MARK: - Realtime

    private func subscribeToRealtime() async {
        let channel = supabase.client.realtimeV2.channel("files-changes")

        let insertions = channel.postgresChange(InsertAction.self, table: "files")
        let deletions = channel.postgresChange(DeleteAction.self, table: "files")

        await channel.subscribe()
        self.realtimeChannel = channel

        Task {
            for await insert in insertions {
                if let item = try? insert.decodeRecord(as: FileItem.self, decoder: JSONDecoder.supabaseDecoder) {
                    await MainActor.run {
                        if !files.contains(where: { $0.id == item.id }) {
                            files.insert(item, at: 0)
                        }
                    }
                }
            }
        }

        Task {
            for await delete in deletions {
                if let idString = delete.oldRecord["id"]?.stringValue,
                   let id = UUID(uuidString: idString) {
                    await MainActor.run {
                        files.removeAll { $0.id == id }
                    }
                }
            }
        }
    }

    private func unsubscribeFromRealtime() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            self.realtimeChannel = nil
        }
    }

    // MARK: - Helpers

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func mimeType(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        let types: [String: String] = [
            "pdf": "application/pdf",
            "png": "image/png",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "gif": "image/gif",
            "txt": "text/plain",
            "json": "application/json",
            "csv": "text/csv",
        ]
        return types[ext] ?? "application/octet-stream"
    }
}

// MARK: - Supabase JSON Decoder

private extension JSONDecoder {
    static let supabaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
