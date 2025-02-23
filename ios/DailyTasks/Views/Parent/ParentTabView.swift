import SwiftUI

struct ParentTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        TabView {
            TaskListView(viewModel: TaskListViewModel(userRole: .parent))
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
            
            DeviceManagementView()
                .tabItem {
                    Label("Devices", systemImage: "wifi")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct ParentTabView_Previews: PreviewProvider {
    static var previews: some View {
        ParentTabView()
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(TaskManager.shared)
    }
} 