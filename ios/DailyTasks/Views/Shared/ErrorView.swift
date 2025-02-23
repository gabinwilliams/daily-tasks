import SwiftUI

struct ErrorView: View {
    let error: Error
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("An Error Occurred")
                .font(.title)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if showDetails {
                Text(String(describing: error))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
            
            Button(action: { showDetails.toggle() }) {
                Text(showDetails ? "Hide Details" : "Show Details")
                    .foregroundColor(.blue)
            }
            .padding(.top)
        }
        .padding()
    }
}

struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorView(error: NSError(domain: "com.dailytasks", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Something went wrong. Please try again."
        ]))
    }
} 