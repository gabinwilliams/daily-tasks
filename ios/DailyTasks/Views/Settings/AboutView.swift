import SwiftUI

struct AboutView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image("AppIcon")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                    
                    Text("Daily Tasks")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            Section("About") {
                Text("Daily Tasks is a comprehensive solution for managing children's daily tasks and automated WiFi access control for gaming consoles and tablets.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Section("Features") {
                featureRow("Task Management", "Create and manage daily tasks")
                featureRow("Photo Proof", "Submit photo evidence of completed tasks")
                featureRow("WiFi Control", "Automatic device access management")
                featureRow("Parent Review", "Approve or reject completed tasks")
            }
            
            Section("Technologies") {
                techRow("iOS App", "Built with SwiftUI")
                techRow("Backend", "AWS Serverless Architecture")
                techRow("Network", "Raspberry Pi Controller")
                techRow("Security", "End-to-end encryption")
            }
            
            Section("Credits") {
                Text("© 2024 Daily Tasks. All rights reserved.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func featureRow(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func techRow(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AboutView()
        }
    }
} 