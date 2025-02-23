import SwiftUI

struct KidTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        TabView {
            TaskListView(viewModel: TaskListViewModel(userRole: .kid))
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
            
            DeviceStatusView()
                .tabItem {
                    Label("Device", systemImage: "wifi")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct KidTabView_Previews: PreviewProvider {
    static var previews: some View {
        KidTabView()
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(TaskManager.shared)
    }
} 