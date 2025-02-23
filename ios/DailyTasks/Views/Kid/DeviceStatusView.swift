import SwiftUI

struct DeviceStatusView: View {
    @StateObject private var deviceManager = DeviceManager.shared
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var showingError = false
    
    private var userDevices: [Device] {
        guard let currentUser = authManager.currentUser else { return [] }
        return deviceManager.getDevicesForKid(currentUser.id)
    }
    
    var body: some View {
        NavigationView {
            Group {
                if deviceManager.isLoading && userDevices.isEmpty {
                    ProgressView()
                } else if userDevices.isEmpty {
                    EmptyStateView(
                        title: "No Devices",
                        message: "Ask your parent to register your devices.",
                        systemImage: "wifi"
                    )
                } else {
                    deviceList
                }
            }
            .navigationTitle("My Devices")
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = deviceManager.error {
                    Text(error.localizedDescription)
                }
            }
            .refreshable {
                await deviceManager.fetchDevices()
            }
        }
        .onChange(of: deviceManager.error) { error in
            showingError = error != nil
        }
    }
    
    private var deviceList: some View {
        List {
            ForEach(userDevices) { device in
                DeviceStatusRow(device: device)
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}

struct DeviceStatusRow: View {
    let device: Device
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: device.deviceType.icon)
                        .foregroundColor(.accentColor)
                    
                    Text(device.deviceName)
                        .font(.headline)
                }
                
                Text(device.macAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusBadge(isBlocked: device.isBlocked)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct StatusBadge: View {
    let isBlocked: Bool
    
    var body: some View {
        Text(isBlocked ? "Blocked" : "Allowed")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isBlocked ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
            .foregroundColor(isBlocked ? .red : .green)
            .cornerRadius(4)
    }
}

struct DeviceStatusView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceStatusView()
            .environmentObject(AuthenticationManager.shared)
    }
} 