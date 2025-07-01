//
//  OrderTrackingAPIClient.swift
//  Zoobox
//
//  Created by omid on 27/06/2025.
//

import Foundation
import Network

@MainActor
class OrderTrackingAPIClient: ObservableObject {
    static let shared = OrderTrackingAPIClient()
    
    private let session: URLSession
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    @Published var lastError: String?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.session = URLSession(configuration: config)
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                if path.status == .satisfied {
                    self?.lastError = nil
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    func checkOrders(userId: String) async throws -> OrderResponse {
        guard isConnected else {
            throw OrderTrackingError.noConnection
        }
        
        guard let url = URL(string: BackgroundTaskConfig.apiEndpoint) else {
            throw OrderTrackingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Add user_id as query parameter
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        
        guard let finalURL = components?.url else {
            throw OrderTrackingError.invalidURL
        }
        
        request.url = finalURL
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OrderTrackingError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw OrderTrackingError.serverError(httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .useDefaultKeys
            
            let orderResponse = try decoder.decode(OrderResponse.self, from: data)
            
            // Reset error state on successful request
            lastError = nil
            
            return orderResponse
            
        } catch let decodingError as DecodingError {
            print("🔍 JSON Decoding Error: \(decodingError)")
            throw OrderTrackingError.decodingError(decodingError.localizedDescription)
        } catch {
            print("🔍 API Request Error: \(error)")
            lastError = error.localizedDescription
            throw OrderTrackingError.networkError(error.localizedDescription)
        }
    }
    
    func getTrackingURL(orderId: String, date: String) -> URL? {
        var components = URLComponents(string: BackgroundTaskConfig.trackingEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "order_id", value: orderId),
            URLQueryItem(name: "date", value: date)
        ]
        return components?.url
    }
    
    deinit {
        networkMonitor.cancel()
    }
}

// MARK: - Error Types
enum OrderTrackingError: LocalizedError {
    case noConnection
    case invalidURL
    case invalidResponse
    case serverError(Int)
    case decodingError(String)
    case networkError(String)
    case noUserId
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error with status code: \(code)"
        case .decodingError(let message):
            return "Failed to parse server response: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .noUserId:
            return "User ID not available"
        }
    }
}

// MARK: - Retry Logic
extension OrderTrackingAPIClient {
    func checkOrdersWithRetry(userId: String, maxRetries: Int = 3) async throws -> OrderResponse {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await checkOrders(userId: userId)
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = TimeInterval(pow(2.0, Double(attempt - 1)))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? OrderTrackingError.networkError("Max retries exceeded")
    }
} 