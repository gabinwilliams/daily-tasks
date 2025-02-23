import SwiftUI

struct NewDeviceView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var deviceManager = DeviceManager.shared
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var deviceName = ""
    @State private var macAddress = ""
    @State private var selectedDeviceType = DeviceType.tablet
    @State private var selectedKidId: String?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showingError = false
    
    private var kids: [User] {
        // In a real app, this would come from the AuthenticationManager
        // For now, we'll return an empty array
        []
    }
    
    private var isFormValid: Bool {
        !deviceName.isEmpty &&
        !macAddress.isEmpty &&
        selectedKidId != nil &&
        deviceManager.validateMacAddress(macAddress)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Device Information")) {
                    TextField("Device Name", text: $deviceName)
                        .textContentType(.name)
                        .autocapitalization(.words)
                    
                    TextField("MAC Address", text: $macAddress)
                        .textInputAutocapitalization(.characters)
                        .textCase(.uppercase)
                    
                    Picker("Device Type", selection: $selectedDeviceType) {
                        ForEach(DeviceType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
                
                Section(header: Text("Assign To")) {
                    if kids.isEmpty {
                        Text("No kids available")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Kid", selection: $selectedKidId) {
                            Text("Select a kid").tag(nil as String?)
                            ForEach(kids) { kid in
                                Text(kid.email)
                                    .tag(kid.id as String?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        registerDevice()
                    }
                    .disabled(!isFormValid || isLoading)
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
        }
    }
    
    private func registerDevice() {
        guard let kidId = selectedKidId else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                try await deviceManager.registerDevice(
                    kidId: kidId,
                    macAddress: macAddress,
                    deviceName: deviceName,
                    deviceType: selectedDeviceType
                )
                dismiss()
            } catch {
                self.error = error
                self.showingError = true
            }
            isLoading = false
        }
    }
}

struct NewDeviceView_Previews: PreviewProvider {
    static var previews: some View {
        NewDeviceView()
            .environmentObject(AuthenticationManager.shared)
    }
} 