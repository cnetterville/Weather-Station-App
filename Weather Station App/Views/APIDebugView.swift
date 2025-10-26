//
//  APIDebugView.swift
//  Weather Station App
//
//  Created by Curtis Netterville on 10/25/25.
//

import SwiftUI

struct APIDebugView: View {
    @State private var testURL: String = ""
    @State private var response: String = ""
    @State private var isLoading: Bool = false
    @State private var statusCode: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("API URL Tester")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Paste an API URL here to test it directly:")
                .foregroundColor(.secondary)
            
            TextField("Paste API URL here", text: $testURL)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .monospaced))
            
            HStack {
                Button("Test URL") {
                    testAPIURL()
                }
                .buttonStyle(.borderedProminent)
                .disabled(testURL.isEmpty || isLoading)
                
                Button("Clear") {
                    testURL = ""
                    response = ""
                    statusCode = 0
                }
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if statusCode > 0 {
                Text("HTTP Status: \(statusCode)")
                    .font(.headline)
                    .foregroundColor(statusCode == 200 ? .green : .red)
            }
            
            if !response.isEmpty {
                Text("Response:")
                    .font(.headline)
                
                ScrollView {
                    Text(response)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .frame(width: 800, height: 600)
    }
    
    private func testAPIURL() {
        guard let url = URL(string: testURL) else {
            response = "Invalid URL"
            return
        }
        
        isLoading = true
        response = ""
        statusCode = 0
        
        Task {
            do {
                let (data, urlResponse) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = urlResponse as? HTTPURLResponse {
                    statusCode = httpResponse.statusCode
                }
                
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                
                await MainActor.run {
                    response = responseString
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    response = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    APIDebugView()
}