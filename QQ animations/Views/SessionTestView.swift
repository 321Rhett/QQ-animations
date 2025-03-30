import SwiftUI

struct SessionTestView: View {
    @StateObject private var viewModel = SessionsViewModel()
    @State private var newSessionName = ""
    
    var body: some View {
        VStack {
            Text("Session Test")
                .font(.title)
            
            TextField("New Session Name", text: $newSessionName)
                .padding()
                .border(Color.gray)
            
            Button("Create Session") {
                if !newSessionName.isEmpty {
                    _ = viewModel.createSession(name: newSessionName)
                    newSessionName = ""
                }
            }
            .padding()
            
            List {
                ForEach(viewModel.sessions) { session in
                    HStack {
                        Text(session.name)
                        Spacer()
                        Text(formatDate(session.creationDate))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .onDelete(perform: deleteSession)
            }
        }
        .padding()
        .onAppear {
            viewModel.loadSessions()
        }
    }
    
    private func deleteSession(at offsets: IndexSet) {
        for index in offsets {
            let session = viewModel.sessions[index]
            _ = viewModel.deleteSession(sessionId: session.id)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SessionTestView()
} 