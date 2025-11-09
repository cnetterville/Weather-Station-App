//
//  APICredentialsSync.swift
//  Weather Station App
//
//  Manages iCloud syncing for API Configuration Keys
//

import Foundation
import Combine

/// Manages synchronization of API credentials across devices using iCloud Key-Value Store
class APICredentialsSync: ObservableObject {
    static let shared = APICredentialsSync()
    
    // iCloud Key-Value Store
    private let cloudStore = NSUbiquitousKeyValueStore.default
    
    // Keys for iCloud storage
    private enum CloudKey {
        static let applicationKey = "com.weatherstation.apiCredentials.applicationKey"
        static let apiKey = "com.weatherstation.apiCredentials.apiKey"
        static let lastModified = "com.weatherstation.apiCredentials.lastModified"
    }
    
    // Keys for local storage (UserDefaults)
    private enum LocalKey {
        static let credentials = "WeatherStationCredentials"
        static let lastModified = "APICredentialsLastModified"
    }
    
    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published var isSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: "iCloudSyncEnabled")
            if isSyncEnabled {
                // Re-enable sync
                setupCloudObserver()
                Task {
                    await performInitialSync()
                }
            } else {
                // Disable sync
                disableSync()
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var cloudObserver: NSObjectProtocol?
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
        case disabled
    }
    
    private init() {
        // Load sync enabled preference (default to true)
        self.isSyncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        
        if isSyncEnabled {
            setupCloudObserver()
            
            // Perform initial sync check when app launches
            Task {
                await performInitialSync()
            }
        } else {
            syncStatus = .disabled
        }
    }
    
    // MARK: - Setup
    
    private func setupCloudObserver() {
        // Remove any existing observer
        if let observer = cloudObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Only set up observer if sync is enabled
        guard isSyncEnabled else { return }
        
        // Observe changes from iCloud
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore,
            queue: .main
        ) { [weak self] notification in
            self?.handleCloudStoreChange(notification)
        }
        
        // Synchronize immediately to get any pending changes
        cloudStore.synchronize()
    }
    
    private func disableSync() {
        // Remove cloud observer
        if let observer = cloudObserver {
            NotificationCenter.default.removeObserver(observer)
            cloudObserver = nil
        }
        
        // Update status
        Task {
            await MainActor.run {
                syncStatus = .disabled
                lastSyncDate = nil
            }
        }
        
        logSync("🚫 iCloud sync disabled")
    }
    
    // MARK: - Sync Operations
    
    /// Performs initial sync when app launches - downloads from iCloud if newer
    private func performInitialSync() async {
        guard isSyncEnabled else {
            await MainActor.run {
                syncStatus = .disabled
            }
            return
        }
        
        await MainActor.run {
            syncStatus = .syncing
        }
        
        // Get local credentials
        let localCredentials = loadLocalCredentials()
        let localModified = loadLocalModificationDate()
        
        // Get cloud credentials
        let cloudCredentials = loadCloudCredentials()
        let cloudModified = loadCloudModificationDate()
        
        // Determine which is newer
        if let cloudModified = cloudModified, let localModified = localModified {
            if cloudModified > localModified {
                // Cloud is newer, download
                logSync("☁️ Cloud credentials are newer, downloading...")
                saveLocalCredentials(cloudCredentials)
                saveLocalModificationDate(cloudModified)
                await updateSyncStatus(.success, date: cloudModified)
            } else if localModified > cloudModified {
                // Local is newer, upload
                logSync("📱 Local credentials are newer, uploading...")
                saveCloudCredentials(localCredentials)
                saveCloudModificationDate(localModified)
                await updateSyncStatus(.success, date: localModified)
            } else {
                // Same modification date, already in sync
                logSync("✅ Credentials already in sync")
                await updateSyncStatus(.success, date: localModified)
            }
        } else if cloudModified != nil {
            // Only cloud has data, download
            logSync("☁️ Downloading credentials from iCloud...")
            saveLocalCredentials(cloudCredentials)
            if let date = cloudModified {
                saveLocalModificationDate(date)
                await updateSyncStatus(.success, date: date)
            }
        } else if localModified != nil {
            // Only local has data, upload
            logSync("📱 Uploading credentials to iCloud...")
            saveCloudCredentials(localCredentials)
            if let date = localModified {
                saveCloudModificationDate(date)
                await updateSyncStatus(.success, date: date)
            }
        } else {
            // Neither has data
            await updateSyncStatus(.idle, date: nil)
        }
    }
    
    /// Saves credentials to both local and iCloud storage
    func saveCredentials(_ credentials: APICredentials) {
        logSync("💾 Saving credentials to local storage...")
        
        let now = Date()
        
        // Always save locally
        saveLocalCredentials(credentials)
        saveLocalModificationDate(now)
        
        // Only save to iCloud if sync is enabled
        if isSyncEnabled {
            logSync("☁️ Saving credentials to iCloud...")
            saveCloudCredentials(credentials)
            saveCloudModificationDate(now)
            
            // Trigger sync
            cloudStore.synchronize()
            
            Task {
                await updateSyncStatus(.success, date: now)
            }
        } else {
            logSync("🚫 iCloud sync disabled, skipping cloud save")
            Task {
                await updateSyncStatus(.disabled, date: nil)
            }
        }
    }
    
    /// Loads credentials, preferring the most recent version
    func loadCredentials() -> APICredentials {
        // If sync is disabled, only use local credentials
        guard isSyncEnabled else {
            logSync("🚫 iCloud sync disabled, using local credentials only")
            return loadLocalCredentials()
        }
        
        let localCredentials = loadLocalCredentials()
        let localModified = loadLocalModificationDate()
        
        let cloudCredentials = loadCloudCredentials()
        let cloudModified = loadCloudModificationDate()
        
        // Return the newer version
        if let cloudModified = cloudModified, let localModified = localModified {
            if cloudModified > localModified {
                logSync("☁️ Using cloud credentials (newer)")
                return cloudCredentials
            } else {
                logSync("📱 Using local credentials (newer)")
                return localCredentials
            }
        } else if cloudModified != nil {
            logSync("☁️ Using cloud credentials (only source)")
            return cloudCredentials
        } else {
            logSync("📱 Using local credentials (only source)")
            return localCredentials
        }
    }
    
    // MARK: - Cloud Storage Handlers
    
    private func handleCloudStoreChange(_ notification: Notification) {
        // Only process if sync is enabled
        guard isSyncEnabled else { return }
        
        guard let userInfo = notification.userInfo else { return }
        
        // Check the reason for the notification
        let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        
        switch reason {
        case NSUbiquitousKeyValueStoreServerChange:
            logSync("🔄 Cloud store changed on server, syncing...")
            handleServerChange(userInfo)
            
        case NSUbiquitousKeyValueStoreInitialSyncChange:
            logSync("🔄 Initial cloud sync completed")
            handleServerChange(userInfo)
            
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            logSync("⚠️ iCloud quota violation")
            Task {
                await updateSyncStatus(.error("iCloud storage quota exceeded"), date: nil)
            }
            
        case NSUbiquitousKeyValueStoreAccountChange:
            logSync("🔄 iCloud account changed, re-syncing...")
            Task {
                await performInitialSync()
            }
            
        default:
            break
        }
    }
    
    private func handleServerChange(_ userInfo: [AnyHashable: Any]) {
        guard let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }
        
        // Check if any of our API credential keys changed
        let relevantKeys = [
            CloudKey.applicationKey,
            CloudKey.apiKey,
            CloudKey.lastModified
        ]
        
        let hasRelevantChanges = changedKeys.contains { relevantKeys.contains($0) }
        
        guard hasRelevantChanges else { return }
        
        // Get cloud credentials
        let cloudCredentials = loadCloudCredentials()
        let cloudModified = loadCloudModificationDate() ?? Date()
        
        let localModified = loadLocalModificationDate() ?? Date.distantPast
        
        // Only update local if cloud is newer (handle conflicts)
        if cloudModified > localModified {
            logSync("☁️ Updating local credentials from iCloud")
            saveLocalCredentials(cloudCredentials)
            saveLocalModificationDate(cloudModified)
            
            // Notify observers that credentials changed
            NotificationCenter.default.post(
                name: .apiCredentialsDidChange,
                object: nil,
                userInfo: ["credentials": cloudCredentials]
            )
            
            Task {
                await updateSyncStatus(.success, date: cloudModified)
            }
        } else {
            logSync("📱 Local credentials are newer, keeping local version")
        }
    }
    
    // MARK: - Local Storage
    
    private func saveLocalCredentials(_ credentials: APICredentials) {
        if let data = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(data, forKey: LocalKey.credentials)
        }
    }
    
    private func loadLocalCredentials() -> APICredentials {
        if let data = UserDefaults.standard.data(forKey: LocalKey.credentials),
           let credentials = try? JSONDecoder().decode(APICredentials.self, from: data) {
            return credentials
        }
        return APICredentials(applicationKey: "", apiKey: "")
    }
    
    private func saveLocalModificationDate(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: LocalKey.lastModified)
    }
    
    private func loadLocalModificationDate() -> Date? {
        let interval = UserDefaults.standard.double(forKey: LocalKey.lastModified)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }
    
    // MARK: - Cloud Storage
    
    private func saveCloudCredentials(_ credentials: APICredentials) {
        cloudStore.set(credentials.applicationKey, forKey: CloudKey.applicationKey)
        cloudStore.set(credentials.apiKey, forKey: CloudKey.apiKey)
    }
    
    private func loadCloudCredentials() -> APICredentials {
        let applicationKey = cloudStore.string(forKey: CloudKey.applicationKey) ?? ""
        let apiKey = cloudStore.string(forKey: CloudKey.apiKey) ?? ""
        return APICredentials(applicationKey: applicationKey, apiKey: apiKey)
    }
    
    private func saveCloudModificationDate(_ date: Date) {
        cloudStore.set(date.timeIntervalSince1970, forKey: CloudKey.lastModified)
    }
    
    private func loadCloudModificationDate() -> Date? {
        let interval = cloudStore.double(forKey: CloudKey.lastModified)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }
    
    // MARK: - Helpers
    
    @MainActor
    private func updateSyncStatus(_ status: SyncStatus, date: Date?) {
        syncStatus = status
        lastSyncDate = date
    }
    
    /// Manually trigger a synchronization with iCloud
    func forceSynchronize() {
        guard isSyncEnabled else {
            logSync("🚫 Cannot force sync - iCloud sync is disabled")
            return
        }
        
        logSync("🔄 Forcing iCloud synchronization...")
        cloudStore.synchronize()
        
        Task {
            await performInitialSync()
        }
    }
    
    // MARK: - Logging
    
    private func logSync(_ message: String) {
        #if DEBUG
        print("[APICredentialsSync] \(message)")
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let apiCredentialsDidChange = Notification.Name("apiCredentialsDidChange")
}
