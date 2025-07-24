import Foundation
import SwiftUI
import Combine
import UserNotifications
import SDWebImage
import SDWebImageSwiftUI

@MainActor
final class AmiiboService: NSObject, ObservableObject {
    // MARK: - Published Properties
    static let shared = AmiiboService()
    @Published var usage: [String: [String: [AmiiboGames]]] = [:]
    var usageInfo: [String: AmiiboGames] = [:]
    @Published var cachingImageCount = 0
    @Published var cachingProgress: Double = 0.0
    @Published var ownedAmiiboIDs: Set<String> = []
    @Published var allAmiibos: [Amiibo] = []
    @Published var dataSource: String = ""
    @Published var groupedBySeries: [String: [Amiibo]] = [:]
    @Published var showingDetail: Bool = false
    @Published var selectedAmiibo: Amiibo?
    @Published var isSyncing = false
    @Published var animalCrossingSubcategoryMap: [String: [String]] = [:]
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var amiibos: [AmiiboData] = []

    private var cancellables = Set<AnyCancellable>()
    private(set) var hasCachedImages = false
    
    var isOfflineMode: Bool {
        UserDefaults.standard.bool(forKey: "offlineMode")
    }
    func amiibos(forIDs ids: [String]) -> [Amiibo] {
        allAmiibos.filter { ids.contains($0.id) }
    }
    // MARK: - Private State
    private var hasFetched = false
    private var hasLoadedOwnedData = false
    private var shouldAutoSave = false
    private let cacheFilename = "amiibo_cache.json"
    
    // MARK: - Current Username (local simple user)

    @Published var currentUsername: String? {
        didSet {
            Task {
                if let username = currentUsername {
                    await loadOwnedAmiibosLocally(for: username)
                } else {
                    await clearOwnedAmiibos()
                }
            }
        }
    }
    
    //MARK: Animal Crossing Sub
    func loadAnimalCrossingSubcategories() {
        guard let url = Bundle.main.url(forResource: "AnimalCrossingSubcategories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            print("❌ Failed to load AnimalCrossingSubcategories.json")
            return
        }
        animalCrossingSubcategoryMap = decoded
        print("✅ Loaded AC subcategories: \(decoded.keys.joined(separator: ", "))")
    }
    // MARK: - Computed properties
    var filteredAmiibos: [Amiibo] {
        if searchText.isEmpty {
            return allAmiibos
        } else {
            return allAmiibos.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    func isOwned(_ amiibo: Amiibo) -> Bool {
        ownedAmiiboIDs.contains(amiibo.id)
    }
    
    var ownedAmiibos: [Amiibo] {
        allAmiibos.filter { ownedAmiiboIDs.contains($0.id) }
        
    }
    @MainActor
    func toggleOwned(for amiibo: Amiibo) {
        if ownedAmiiboIDs.contains(amiibo.id) {
            ownedAmiiboIDs.remove(amiibo.id)
        } else {
            ownedAmiiboIDs.insert(amiibo.id)
        }
        
        for i in allAmiibos.indices {
            allAmiibos[i].isOwned = ownedAmiiboIDs.contains(allAmiibos[i].id)
        }
        
        saveOwnedAmiibosLocally()  // your existing local save
        updateGrouping()
        
    }

    
    
    // MARK: - Clear cache
    func clearCache() {
        print("🧹 Clearing cache...")
        do {
            try FileManager.default.removeItem(at: cacheURL)
            print("🧹 Cache cleared.")
            allAmiibos = []
            hasFetched = false    // ✅ allow re-fetch
            dataSource = "None"
        } catch {
            print("⚠️ Failed to clear cache: \(error.localizedDescription)")
        }
    }
    func resetAll() {
        do {
            try FileManager.default.removeItem(at: cacheURL)
            print("🧨 Full reset: cache deleted.")
            allAmiibos = []
            ownedAmiiboIDs = []
            hasFetched = false
            dataSource = "None"
            Task {
                await fetchAmiibos(force: true)
            }
        } catch {
            print("⚠️ Failed to reset: \(error.localizedDescription)")
        }
    }
    func clearCacheAndRefetch() {
        clearCache()
        Task {
            await fetchAmiibos(force: true)
        }
    }
    func resetAppData() {
        // Clear caches, user data, etc.
        clearCache()
        // Reset any in-memory data
        allAmiibos.removeAll()
        ownedAmiiboIDs.removeAll()
        usageInfo.removeAll()
        groupedBySeries.removeAll()
        animalCrossingSubcategoryMap.removeAll()
        
        // Trigger fetch after reset
        Task {
            await fetchAmiibos(force: true)
        }
    }
    // MARK: - Init
    override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: .loadOwnedAmiibos, object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            if let username = notification.object as? String {
                print("🛎️ Notification received to load owned Amiibos for user \(username)")
                self.currentUsername = username
            } else {
                print("🛎️ Notification received for logout, clearing owned Amiibos")
                self.currentUsername = nil
            }
        }
        self.shouldAutoSave = false // prevent auto-save on init load
        loadFromCacheIfAvailable()
        loadUsageData()
        loadSubcategoriesFromJSON()
        MissingAmiibo.injectIntoService(self)
        print("🔧 AmiiboService initialized")
    }
    
    // MARK: - Data Grouping
    @MainActor
    func updateGrouping() {
        groupedBySeries = Dictionary(grouping: allAmiibos, by: { $0.gameSeries ?? "Unknown" })
        let ownedAmiibos = allAmiibos.filter { $0.isOwned }
        // groupedBySeries["Owned"] = ownedAmiibos
    }
    
    // MARK: - Fetch / Cache
    
    var cacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(cacheFilename)
    }
    
    func loadFromCacheIfAvailable() {
        if FileManager.default.fileExists(atPath: cacheURL.path),
           let data = try? Data(contentsOf: cacheURL) {
            print("📦 Loading from cache: \(data.count) bytes")
            decodeAndStore(from: data)
        } else {
            print("📭 No cache found")
        }
    }
    func testSingleAmiiboNotification() {
        let fakeNewAmiibo = "Test Amiibo"
        notifyAboutNewAmiibo(names: [fakeNewAmiibo])
    }
    
    func decodeAndStore(from data: Data) {
        do {
            let decoded = try JSONDecoder().decode(AmiiboResponse.self, from: data)
            allAmiibos = decoded.amiibo
            print("✅ Decoded \(allAmiibos.count) amiibos")
            
            // 1️⃣ Extract fetched IDs
            let fetchedIDs = decoded.amiibo.map { $0.id }
            
            // 2️⃣ Load previously known IDs from AppStorage
            let oldIDs = knownAmiiboIDs
            let newIDs = fetchedIDs.filter { !oldIDs.contains($0) }
            
            // 3️⃣ If any new IDs, send notification
            if !newIDs.isEmpty {
                let newNames = decoded.amiibo
                    .filter { newIDs.contains($0.id) }
                    .map { $0.name }
                
                notifyAboutNewAmiibo(names: newNames)
            }
            
            // 4️⃣ Update known IDs with new set
            knownAmiiboIDs = Set(fetchedIDs)
            
            // 5️⃣ Save + regroup
            saveToCache(data)
            updateGrouping()
            
        } catch {
            print("❌ Decode error: \(error.localizedDescription)")
        }
    }
    
    func updateOwnedAmiibos(_ updatedList: [Amiibo]) {
        self.ownedAmiiboIDs = Set(updatedList.map { $0.id })
#if os(iOS)
        let ownedAmiibos = amiibos(forIDs: Array(ownedAmiiboIDs))
#endif
    }
    func notifyAboutNewAmiibo(names: [String]) {
#if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "🎉 New Amiibo Available"
        
        if names.count == 1 {
            content.body = names.first ?? "A new Amiibo has arrived!"
        } else {
            content.body = "\(names.count) new Amiibo have arrived: \(names.joined(separator: ", "))"
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Notification error: \(error.localizedDescription)")
            } else {
                print("✅ Notification scheduled successfully")
            }
        }
#else
        print("UserNotifications framework is not available on this platform.")
#endif
    }
    
    private func saveToCache(_ data: Data) {
        do {
            try data.write(to: cacheURL)
            print("💾 Saved amiibo data to cache")
        } catch {
            print("❌ Failed to save cache: \(error.localizedDescription)")
        }
    }
    @AppStorage("knownAmiiboIDs") private var knownAmiiboIDsData: Data = Data()
    
    private var knownAmiiboIDs: Set<String> {
        get {
            (try? JSONDecoder().decode(Set<String>.self, from: knownAmiiboIDsData)) ?? []
        }
        set {
            knownAmiiboIDsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
    @MainActor
    func fetchAmiibos(force: Bool = false) async {
        if isOfflineMode {
            print("🚫 Offline mode active. Skipping API fetch.")
            return
        }
        
        guard force || !hasFetched else {
            print("🛑 Already fetched. Source: \(dataSource)")
            return
        }
        guard !isLoading || force else {
            print("⚠️ Already loading, skipping fetch.")
            return
        }
        isLoading = true
        defer { isLoading = false; hasFetched = true }
        
        if !force,
           FileManager.default.fileExists(atPath: cacheURL.path),
           let cached = try? Data(contentsOf: cacheURL) {
            print("📦 Loaded from cache at: \(cacheURL.path)")
            decodeAndStore(from: cached)
            dataSource = "Cache"
            return
        }
        
        print("🌐 Fetching from API...")
        do {
            let url = URL(string: "https://www.amiiboapi.com/api/amiibo/")!
            let (data, _) = try await URLSession.shared.data(from: url)
            saveToCache(data)
            decodeAndStore(from: data)
            dataSource = "API"
        } catch {
            print("❌ Failed to fetch or save: \(error.localizedDescription)")
        }
        
        // Now that amiibos have been loaded, cache images
        await withTaskGroup(of: Void.self) { group in
            for amiibo in allAmiibos {
                group.addTask {
                    await self.cacheImage(for: amiibo)
                }
            }
        }
    }
    
    // MARK: - Local persistence keys per user
    private func ownedKey(for username: String) -> String {
        "ownedAmiiboIDs_\(username)"
    }
    
    @MainActor
    func loadOwnedAmiibosLocally(for username: String) async {
        let key = ownedKey(for: username)
        if let data = UserDefaults.standard.data(forKey: key),
           let savedIDs = try? JSONDecoder().decode(Set<String>.self, from: data) {
            ownedAmiiboIDs = savedIDs
        } else {
            ownedAmiiboIDs = []
        }
        print("📥 Loaded owned Amiibos for user \(username): \(ownedAmiiboIDs.count) items")
    }
    
    func saveOwnedAmiibosLocally() {
        guard let username = currentUsername else { return }
        let key = ownedKey(for: username)
        if let data = try? JSONEncoder().encode(ownedAmiiboIDs) {
            UserDefaults.standard.set(data, forKey: key)
            print("💾 Saved owned Amiibos for user \(username): \(ownedAmiiboIDs.count) items")
        }
    }
    // MARK: - Clear owned Amiibos on logout
    @MainActor
    func clearOwnedAmiibos() {
        saveOwnedAmiibosLocally()  // Make sure local storage is updated
        ownedAmiiboIDs.removeAll()
    }
    var userOwnedAmiiboURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("user_owned_amiibo.json")
    }
    // MARK: - Caching Images
    @MainActor
    func cacheImage(for amiibo: Amiibo) async {
        cachingImageCount += 1
        defer { cachingImageCount -= 1 }
        
        // Your existing caching logic here
        guard let imageURL = amiibo.imageURL else { return }  // Use `imageURL` property on Amiibo (optional URL)
        guard let imagePath = cachedImagePath(for: amiibo) else { return }  // Unwrap optional URL
        
        guard !FileManager.default.fileExists(atPath: imagePath.path) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            try data.write(to: imagePath)
            print("📥 Cached image for \(amiibo.name)")
        } catch {
            print("❌ Failed to cache image for \(amiibo.name): \(error.localizedDescription)")
        }
    }
    var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    func cachedImagePath(for amiibo: Amiibo) -> URL? {
        let filename = amiibo.id + ".png"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    func prefetchImagesIfNeeded() {
        if isOfflineMode {
            print("🚫 Offline mode active. Skipping image caching.")
            return
        }
        guard !hasCachedImages, !allAmiibos.isEmpty else { return }
        hasCachedImages = true
        cachingProgress = 0.0
        let urls = allAmiibos.compactMap { $0.imageURL }
        SDWebImagePrefetcher.shared.prefetchURLs(urls, progress: { completed, total in
            DispatchQueue.main.async {
                self.cachingProgress = total > 0 ? Double(completed) / Double(total) : 1.0
            }
        }, completed: { finished, skipped in
            DispatchQueue.main.async {
                self.cachingProgress = 1.0
            }
            print("✅ Done caching! Skipped: \(skipped)")
        })
    }
    /// Prefetch all Amiibo images and update progress
    func prefetchAmiiboImages() {
        let urls = allAmiibos.compactMap { $0.imageURL }
        let totalCount = urls.count
        guard totalCount > 0 else { return }
        
        cachingProgress = 0.0
        
        var completedCount = 0
        
        for url in urls {
            SDWebImageManager.shared.loadImage(with: url, options: [], progress: nil) { [weak self] _, _, _, _, _, _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    completedCount += 1
                    self.cachingProgress = Double(completedCount) / Double(totalCount)
                }
            }
        }
    }
    func resetCachingProgress() {
        cachingProgress = 0.0
    }
    
    // Optionally, call this from your fetch or wherever you want to start caching:
    func fetchAmiibosAndCacheImages(force: Bool = false) async {
        await fetchAmiibos(force: force)
        for amiibo in allAmiibos {
            await cacheImage(for: amiibo)
        }
        prefetchAmiiboImages() // optional, for SDWebImage cache
    }
    
    // MARK: - Load Usage Data
    // Convert from MissingAmiibo (manual data with [GameUsage]) to AmiiboGames (full model with [AmiiboGameUsage])
    func convertToAmiiboGames(from missing: MissingAmiibo) -> AmiiboGames {
        
        // Convert [GameUsage] to [AmiiboGameUsage]
        func convertUsages(_ games: [MissingAmiibo.GameUsage]) -> [AmiiboGameUsage] {
            return games.map { game in
                AmiiboGameUsage(
                    gameName: game.name,
                    gameID: [], // You can leave empty or provide IDs if you have them
                    amiiboUsage: game.usage.map { usageString in
                        AmiiboUsage(usage: usageString, write: false) // Assuming write false; adjust if needed
                    }
                )
            }
        }

        return AmiiboGames(
            gamesSwitch: convertUsages(missing.gamesSwitch),
            games3DS: convertUsages(missing.games3DS),
            gamesWiiU: convertUsages(missing.gamesWiiU)
        )
    }

    func loadUsageData() {
        guard let url = Bundle.main.url(forResource: "games_info_compact", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(GamesInfoCompact.self, from: data) else {
            print("❌ Failed to load or decode games_info_compact.json")
            return
        }
        
        var normalized: [String: AmiiboGames] = [:]
        
        // Here, you must convert CompactAmiiboGames (decoded) to AmiiboGames (full model)
        for (key, compactValue) in decoded.amiibos {
            let normalizedKey = key.hasPrefix("0x") ? String(key.dropFirst(2)) : key
            
            // Convert compactValue (CompactAmiiboGames) to AmiiboGames
            let converted = AmiiboGames(
                gamesSwitch: compactValue.games.switchGames?.map {
                    AmiiboGameUsage(
                        gameName: $0.name,
                        gameID: [],
                        amiiboUsage: [AmiiboUsage(usage: $0.usage, write: false)]
                    )
                } ?? [], games3DS: compactValue.games.n3ds?.map {
                    AmiiboGameUsage(
                        gameName: $0.name,
                        gameID: [],
                        amiiboUsage: [AmiiboUsage(usage: $0.usage, write: false)]
                    )
                } ?? [],
                gamesWiiU: compactValue.games.wiiu?.map {
                    AmiiboGameUsage(
                        gameName: $0.name,
                        gameID: [],
                        amiiboUsage: [AmiiboUsage(usage: $0.usage, write: false)]
                    )
                } ?? []
            )
            
            normalized[normalizedKey] = converted
        }
        
        // Add your manual missing Amiibos converted to full AmiiboGames model
        for missing in MissingAmiibo.all {
            let key = missing.head + missing.tail
            let converted = convertToAmiiboGames(from: missing)
            normalized[key] = converted
        }
        
        usageInfo = normalized
        print("✅ Loaded usage info for \(usageInfo.count) amiibos")
    }
    
    func usage(for amiiboID: String) -> AmiiboGames? {
        let normalizedID = amiiboID.lowercased().replacingOccurrences(of: "0x", with: "")
        return usageInfo[normalizedID]
    }
    
    // MARK: - Load Animal Crossing Subcategories
    func loadSubcategoriesFromJSON() {
        guard let url = Bundle.main.url(forResource: "AnimalCrossingSubcategories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            print("❌ Failed to load AnimalCrossingSubcategories.json")
            return
        }
        // Strip "0x" prefix from all IDs for easier matching
        var cleanedMap = [String: [String]]()
        for (key, idList) in decoded {
            cleanedMap[key] = idList.map { $0.hasPrefix("0x") ? String($0.dropFirst(2)) : $0 }
        }
        animalCrossingSubcategoryMap = cleanedMap
        print("✅ Loaded subcategories: \(cleanedMap.keys.joined(separator: ", "))")
    }
    
    // MARK: - Helper
    func amiibos(forSubcategory subcategory: String) -> [Amiibo] {
        guard let ids = animalCrossingSubcategoryMap[subcategory] else { return [] }
        
        let normalizedIDs = ids.map { $0.hasPrefix("0x") ? String($0.dropFirst(2)) : $0 }
        let filtered = allAmiibos.filter { amiibo in
            let match = normalizedIDs.contains(amiibo.id.lowercased())
            if match {
                print("Matched amiibo \(amiibo.name) with id \(amiibo.id)")
            }
            return match
        }
        print("Subcategory '\(subcategory)' has \(filtered.count) amiibos")
        return filtered
    }
}
// Notification extension for loading owned amiibos event
extension NSNotification.Name {
    static let loadOwnedAmiibos = NSNotification.Name("loadOwnedAmiibos")
}


