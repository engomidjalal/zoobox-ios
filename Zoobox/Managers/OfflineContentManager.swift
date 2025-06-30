import Foundation
import WebKit
import UIKit

protocol OfflineContentManagerDelegate: AnyObject {
    func offlineContentManager(_ manager: OfflineContentManager, didUpdateCacheSize size: Int64)
    func offlineContentManager(_ manager: OfflineContentManager, didEncounterError error: Error)
    func offlineContentManager(_ manager: OfflineContentManager, didCompleteCaching url: URL)
}

class OfflineContentManager: NSObject {
    static let shared = OfflineContentManager()
    
    weak var delegate: OfflineContentManagerDelegate?
    
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let fileManager = FileManager.default
    
    private var isCaching = false
    private var cachedURLs: Set<URL> = []
    
    override init() {
        // Create cache directory in app's documents folder
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("OfflineCache")
        
        super.init()
        
        createCacheDirectoryIfNeeded()
        loadCachedURLs()
    }
    
    // MARK: - Public Methods
    
    func startCaching(for url: URL) {
        guard !isCaching else { return }
        
        isCaching = true
        cacheWebPage(url: url)
    }
    
    func stopCaching() {
        isCaching = false
    }
    
    func clearCache() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for url in contents {
                try fileManager.removeItem(at: url)
            }
            cachedURLs.removeAll()
            saveCachedURLs()
            delegate?.offlineContentManager(self, didUpdateCacheSize: 0)
        } catch {
            delegate?.offlineContentManager(self, didEncounterError: error)
        }
    }
    
    func getCacheSize() -> Int64 {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            var totalSize: Int64 = 0
            
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
            
            return totalSize
        } catch {
            return 0
        }
    }
    
    func hasCachedContent() -> Bool {
        return !cachedURLs.isEmpty
    }
    
    func getCachedContent(for url: URL) -> Data? {
        let fileName = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? url.lastPathComponent
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        return try? Data(contentsOf: fileURL)
    }
    
    func isURLCached(_ url: URL) -> Bool {
        return cachedURLs.contains(url)
    }
    
    func getOfflineHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Offline - Zoobox</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background: linear-gradient(135deg, #dc3545 0%, #b71c1c 100%);
                    min-height: 100vh;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .container {
                    background: white;
                    border-radius: 20px;
                    padding: 40px;
                    text-align: center;
                    box-shadow: 0 20px 40px rgba(0,0,0,0.1);
                    max-width: 400px;
                    width: 100%;
                }
                .icon {
                    font-size: 80px;
                    margin-bottom: 20px;
                }
                h1 {
                    color: #333;
                    margin-bottom: 10px;
                    font-size: 28px;
                    font-weight: bold;
                }
                p {
                    color: #666;
                    margin-bottom: 30px;
                    line-height: 1.6;
                }
                .button {
                    background: #dc3545;
                    color: white;
                    border: none;
                    padding: 15px 30px;
                    border-radius: 12px;
                    font-size: 16px;
                    font-weight: 600;
                    cursor: pointer;
                    margin: 10px;
                    transition: all 0.3s ease;
                }
                .button:hover {
                    background: #b71c1c;
                    transform: translateY(-2px);
                }
                .button.secondary {
                    background: #f8f9fa;
                    color: #333;
                }
                .button.secondary:hover {
                    background: #e9ecef;
                }
                .cached-content {
                    margin-top: 30px;
                    padding: 20px;
                    background: #f8f9fa;
                    border-radius: 12px;
                    border-left: 4px solid #28a745;
                }
                .cached-content h3 {
                    color: #28a745;
                    margin-bottom: 10px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="icon">📱</div>
                <h1>You're Offline</h1>
                <p>Don't worry! You can still access some features and cached content while offline.</p>
                
                <button class="button" onclick="retryConnection()">Try Again</button>
                <button class="button secondary" onclick="checkSettings()">Check Settings</button>
                
                <div class="cached-content">
                    <h3>📦 Cached Content Available</h3>
                    <p>Some pages and content are available offline. Tap "Offline Mode" to access them.</p>
                    <button class="button" onclick="enableOfflineMode()">Offline Mode</button>
                </div>
            </div>
            
            <script>
                function retryConnection() {
                    window.webkit.messageHandlers.retryConnection.postMessage({});
                }
                
                function checkSettings() {
                    window.webkit.messageHandlers.checkSettings.postMessage({});
                }
                
                function enableOfflineMode() {
                    window.webkit.messageHandlers.enableOfflineMode.postMessage({});
                }
                
                // Auto-retry connection every 30 seconds
                setInterval(function() {
                    if (navigator.onLine) {
                        retryConnection();
                    }
                }, 30000);
            </script>
        </body>
        </html>
        """
    }
    
    // MARK: - Private Methods
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create cache directory: \(error)")
            }
        }
    }
    
    private func loadCachedURLs() {
        let urlsFile = cacheDirectory.appendingPathComponent("cached_urls.json")
        
        guard let data = try? Data(contentsOf: urlsFile),
              let urls = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        
        cachedURLs = Set(urls.compactMap { URL(string: $0) })
    }
    
    private func saveCachedURLs() {
        let urlsFile = cacheDirectory.appendingPathComponent("cached_urls.json")
        let urls = Array(cachedURLs.map { $0.absoluteString })
        
        do {
            let data = try JSONEncoder().encode(urls)
            try data.write(to: urlsFile)
        } catch {
            print("Failed to save cached URLs: \(error)")
        }
    }
    
    private func cacheWebPage(url: URL) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.delegate?.offlineContentManager(self, didEncounterError: error)
                    self.isCaching = false
                    return
                }
                
                guard let data = data else {
                    self.isCaching = false
                    return
                }
                
                // Check cache size before saving
                let currentSize = self.getCacheSize()
                if currentSize + Int64(data.count) > self.maxCacheSize {
                    self.cleanupOldCache()
                }
                
                // Save to cache
                let fileName = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? url.lastPathComponent
                let fileURL = self.cacheDirectory.appendingPathComponent(fileName)
                
                do {
                    try data.write(to: fileURL)
                    self.cachedURLs.insert(url)
                    self.saveCachedURLs()
                    
                    let newSize = self.getCacheSize()
                    self.delegate?.offlineContentManager(self, didUpdateCacheSize: newSize)
                    self.delegate?.offlineContentManager(self, didCompleteCaching: url)
                    
                } catch {
                    self.delegate?.offlineContentManager(self, didEncounterError: error)
                }
                
                self.isCaching = false
            }
        }
        
        task.resume()
    }
    
    private func cleanupOldCache() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
            
            // Sort by creation date (oldest first)
            let sortedContents = contents.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 < date2
            }
            
            // Remove oldest files until we're under the limit
            let targetSize = maxCacheSize * 3 / 4 // Keep 75% of max cache size
            
            for url in sortedContents {
                if getCacheSize() <= targetSize {
                    break
                }
                
                try fileManager.removeItem(at: url)
                
                // Remove from cached URLs if it's a cached page
                if let urlString = url.lastPathComponent.removingPercentEncoding,
                   let originalURL = URL(string: urlString) {
                    cachedURLs.remove(originalURL)
                }
            }
            
            saveCachedURLs()
            
        } catch {
            print("Failed to cleanup cache: \(error)")
        }
    }
    
    // MARK: - Cache Management
    
    func cacheCurrentPage(_ webView: WKWebView) {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            guard let self = self,
                  let html = result as? String,
                  let currentURL = webView.url else { return }
            
            let fileName = currentURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? currentURL.lastPathComponent
            let fileURL = self.cacheDirectory.appendingPathComponent(fileName)
            
            do {
                try html.data(using: .utf8)?.write(to: fileURL)
                self.cachedURLs.insert(currentURL)
                self.saveCachedURLs()
                
                let newSize = self.getCacheSize()
                self.delegate?.offlineContentManager(self, didUpdateCacheSize: newSize)
                self.delegate?.offlineContentManager(self, didCompleteCaching: currentURL)
                
            } catch {
                self.delegate?.offlineContentManager(self, didEncounterError: error)
            }
        }
    }
    
    func loadCachedPage(_ url: URL, in webView: WKWebView) {
        guard let data = getCachedContent(for: url),
              let html = String(data: data, encoding: .utf8) else {
            return
        }
        
        webView.loadHTMLString(html, baseURL: url)
    }
}

// MARK: - WKWebView Extension

extension WKWebView {
    func enableOfflineMode() {
        let offlineHTML = OfflineContentManager.shared.getOfflineHTML()
        loadHTMLString(offlineHTML, baseURL: nil)
    }
    
    func cacheCurrentPage() {
        OfflineContentManager.shared.cacheCurrentPage(self)
    }
} 