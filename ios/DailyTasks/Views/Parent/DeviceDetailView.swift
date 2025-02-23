import SwiftUI

struct DeviceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var deviceManager = DeviceManager.shared
    let device: Device
    
    @State private var showingDeleteConfirmation = false
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    deviceInfoRow("Device Name", device.deviceName)
                    deviceInfoRow("MAC Address", device.macAddress)
                    deviceInfoRow("Type", device.deviceType.displayName)
                    deviceInfoRow("Status", device.isBlocked ? "Blocked" : "Allowed")
                }
                
                Section {
                    deviceInfoRow("Created", device.createdAt.formatted())
                    deviceInfoRow("Last Updated", device.updatedAt.formatted())
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Device", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Device Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .disabled(isLoading)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
            .alert("Delete Device", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteDevice()
                }
            } message: {
                Text("Are you sure you want to delete this device? This action cannot be undone.")
            }
        }
    }
    
    private func deviceInfoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
    
    private func deleteDevice() {
        isLoading = true
        error = nil
        
        Task {
            do {
                try await deviceManager.deleteDevice(device)
                dismiss()
            } catch {
                self.error = error
                self.showingError = true
            }
            isLoading = false
        }
    }
}

struct DeviceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceDetailView(device: Device(
            kidId: "kid1",
            macAddress: "00:11:22:33:44:55",
            deviceName: "iPad",
            deviceType: .tablet,
            isBlocked: false,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
} 