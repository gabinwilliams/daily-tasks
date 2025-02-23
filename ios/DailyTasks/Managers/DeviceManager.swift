import Foundation
import Combine

class DeviceManager: ObservableObject {
    static let shared = DeviceManager()
    
    @Published var devices: [Device] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiClient = APIClient.shared
    
    private init() {}
    
    func fetchDevices() async {
        isLoading = true
        error = nil
        
        do {
            let fetchedDevices = try await apiClient.getDevices()
            DispatchQueue.main.async {
                self.devices = fetchedDevices
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func registerDevice(
        kidId: String,
        deviceName: String,
        macAddress: String,
        deviceType: DeviceType
    ) async throws -> Device {
        isLoading = true
        error = nil
        
        do {
            let device = try await apiClient.registerDevice(
                kidId: kidId,
                deviceName: deviceName,
                macAddress: macAddress,
                deviceType: deviceType
            )
            
            DispatchQueue.main.async {
                self.devices.append(device)
                self.isLoading = false
            }
            
            return device
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    func updateDevice(_ device: Device) async throws {
        isLoading = true
        error = nil
        
        do {
            let updatedDevice = try await apiClient.updateDevice(device)
            
            DispatchQueue.main.async {
                if let index = self.devices.firstIndex(where: { $0.id == device.id }) {
                    self.devices[index] = updatedDevice
                }
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    func toggleDeviceAccess(_ device: Device) async throws {
        var updatedDevice = device
        updatedDevice.isBlocked.toggle()
        try await updateDevice(updatedDevice)
    }
    
    func getDevicesForKid(_ kidId: String) -> [Device] {
        devices.filter { $0.kidId == kidId }
    }
    
    func getDevice(withMacAddress macAddress: String) -> Device? {
        devices.first { $0.macAddress == macAddress }
    }
    
    func validateMacAddress(_ macAddress: String) -> Bool {
        let pattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: macAddress.utf16.count)
        return regex?.firstMatch(in: macAddress, range: range) != nil
    }
} 