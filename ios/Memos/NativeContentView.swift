import SwiftUI

struct NativeContentView: View {
    @EnvironmentObject var serverManager: ServerManager
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationView {
            Group {
                if serverManager.isRunning {
                    if authViewModel.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                            Text("Authenticating...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        MemoListView()
                    }
                } else if let error = serverManager.error {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        Text("Server Error")
                            .font(.title)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") {
                            serverManager.startServer()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Starting Memos Server...")
                            .font(.title2)
                    }
                }
            }
            .navigationTitle("Memos")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(serverManager)
            }
        }
        .onChange(of: serverManager.isRunning) { _, isRunning in
            if isRunning {
                Task {
                    await authViewModel.checkAuthentication()
                }
            }
        }
    }
}

#Preview {
    NativeContentView()
        .environmentObject(ServerManager.shared)
}
