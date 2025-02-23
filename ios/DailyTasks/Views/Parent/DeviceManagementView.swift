import SwiftUI

struct DeviceManagementView: View {
    @StateObject private var deviceManager = DeviceManager.shared
    @State private var showingNewDevice = false
    @State private var selectedDevice: Device?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            Group {
                if deviceManager.isLoading && deviceManager.devices.isEmpty {
                    ProgressView()
                } else if deviceManager.devices.isEmpty {
                    EmptyStateView(
                        title: "No Devices",
                        message: "Register your kids' devices to manage their access.",
                        systemImage: "wifi"
                    )
                } else {
                    deviceList
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewDevice = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewDevice) {
                NewDeviceView()
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailView(device: device)
            }
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
            ForEach(deviceManager.devices) { device in
                DeviceRowView(device: device)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDevice = device
                    }
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}

struct DeviceRowView: View {
    let device: Device
    @StateObject private var deviceManager = DeviceManager.shared
    @State private var isToggling = false
    
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
            
            Toggle("", isOn: .init(
                get: { !device.isBlocked },
                set: { newValue in toggleAccess() }
            ))
            .labelsHidden()
            .disabled(isToggling)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
    
    private func toggleAccess() {
        guard !isToggling else { return }
        isToggling = true
        
        Task {
            do {
                try await deviceManager.toggleDeviceAccess(device)
            } catch {
                print("Error toggling device access: \(error.localizedDescription)")
            }
            isToggling = false
        }
    }
}

struct DeviceManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceManagementView()
    }
} 