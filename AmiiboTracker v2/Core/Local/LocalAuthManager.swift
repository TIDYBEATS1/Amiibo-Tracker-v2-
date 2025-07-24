import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class LocalAuthManager: ObservableObject {
    @Published private(set) var username: String? = nil
    @Published private(set) var userUID: String? = nil
    @Published var isLoadingUserAmiibo = true
    @Published var isLoading: Bool = true
    @Published var currentUser: User?
    private var ownedAmiiboListener: ListenerRegistration? = nil
    private var cancellables = Set<AnyCancellable>()
    private var isUpdatingFromFirestore = false
    static let shared = LocalAuthManager(service: AmiiboService.shared)
    private var isPrimingUser = true
    @Published var user: User? = Auth.auth().currentUser
    private var hasReceivedFirestoreData = false
    var service: AmiiboService
    
    
    var isSignedIn: Bool {
        return Auth.auth().currentUser != nil
    }
    
    var userDisplayName: String {
        user?.displayName ?? "Unknown User"
    }
    
    var uid: String? {
        user?.uid
    }
    
    init(service: AmiiboService) {
        self.service = service
        
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.username = user?.displayName ?? user?.email ?? user?.uid
                self?.userUID = user?.uid
                if let uid = user?.uid {
                    self?.startListeningToOwnedAmiibos(for: uid)
                } else {
                    self?.ownedAmiiboListener?.remove()
                    self?.service.ownedAmiiboIDs = []
                }
            }
        }
        
        // Save owned amiibos on changes, avoiding loop when updating from Firestore
        service.$ownedAmiiboIDs
            .removeDuplicates()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.isUpdatingFromFirestore {
                    Task {
                        await self.saveOwnedAmiibosToFirestore()
                    }
                }
            }
            .store(in: &cancellables)
        
        Task {
            await autoLogin()
            
            self.isUpdatingFromFirestore = true
            await loadUserAmiibo()
            self.isUpdatingFromFirestore = false
            
            if let uid = self.userUID {
                self.startListeningToOwnedAmiibos(for: uid)
            }
        }
    }
    
    func autoLogin() async {
        isLoading = true
        // Short delay for simulating async loading
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        if let user = Auth.auth().currentUser {
            self.username = user.displayName ?? user.email ?? user.uid
            self.userUID = user.uid
            self.service.currentUsername = user.uid
        } else {
            self.username = nil
            self.userUID = nil
            self.service.currentUsername = ""
        }
        isLoading = false
    }
    
    func signInAnonymously() async throws {
        isLoading = true
        let result = try await Auth.auth().signInAnonymously()
        let user = result.user
        self.username = "Guest"
        self.userUID = user.uid
        service.currentUsername = user.uid
        startListeningToOwnedAmiibos(for: user.uid)
        isLoading = false
    }
    
    @MainActor
    func signIn(with user: User) async {
        self.username = user.displayName ?? user.email ?? user.uid
        self.userUID = user.uid
        service.currentUsername = user.uid
        startListeningToOwnedAmiibos(for: user.uid)
    }
    func signInWithGitHub() {
        let provider = OAuthProvider(providerID: "github.com")
        provider.scopes = ["user:email"]
        
        provider.getCredentialWith(nil) { credential, error in
            if let error = error {
                print("GitHub Auth error: \(error.localizedDescription)")
                return
            }
            
            guard let credential = credential else {
                print("GitHub Auth: No credential returned")
                return
            }
            
            Auth.auth().signIn(with: credential) { [weak self] result, error in
                if let error = error {
                    print("Firebase SignIn error: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.currentUser = result?.user
                    Task { @MainActor in
                        await self?.signIn(with: result!.user)
                    }
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.username = nil
            self.userUID = nil
            service.currentUsername = ""
            service.ownedAmiiboIDs = []
            ownedAmiiboListener?.remove()
            ownedAmiiboListener = nil
        } catch {
            print("Sign-out error: \(error.localizedDescription)")
        }
    }
    
    // Load owned amiibos once from Firestore document
    private func loadUserOwnedAmiibos(from uid: String) async {
        isLoadingUserAmiibo = true
        do {
            let snapshot = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument()
            
            if let data = snapshot.data(),
               let owned = data["ownedAmiibos"] as? [String] {
                isUpdatingFromFirestore = true
                service.ownedAmiiboIDs = Set(owned)
                isUpdatingFromFirestore = false
            } else {
                service.ownedAmiiboIDs = []
            }
        } catch {
            print("Failed to load amiibos: \(error.localizedDescription)")
            service.ownedAmiiboIDs = []
        }
        isLoadingUserAmiibo = false
    }
    
    // Save owned amiibos to Firestore under user document
    func saveOwnedAmiibosToFirestore() async {
        guard let uid = userUID else {
            print("No user UID, can't save owned amiibos")
            return
        }
        
        let ownedArray = Array(service.ownedAmiiboIDs)
        
        do {
            try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .setData(["ownedAmiibos": ownedArray], merge: true)
            print("Successfully saved owned amiibos to Firestore")
        } catch {
            print("Failed to save owned amiibos: \(error.localizedDescription)")
        }
    }
    
    // Load user's owned amiibos from local JSON cache if available
    func loadUserAmiibo() async {
        isLoadingUserAmiibo = true
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        guard let uid = userUID else {
            service.currentUsername = nil
            isLoadingUserAmiibo = false
            return
        }
        
        service.currentUsername = uid // This triggers ownedAmiiboIDs load from UserDefaults
        
        isLoadingUserAmiibo = false
    }
    
    func startListeningToOwnedAmiibos(for uid: String) {
        ownedAmiiboListener?.remove()
        
        ownedAmiiboListener = Firestore.firestore()
            .collection("users")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Firestore listener error: \(error.localizedDescription)")
                    return
                }
                
                Task { @MainActor in
                    self.isUpdatingFromFirestore = true
                    
                    if let data = snapshot?.data(), let owned = data["ownedAmiibos"] as? [String] {
                        self.service.ownedAmiiboIDs = Set(owned)
                        self.hasReceivedFirestoreData = true
                        print("✅ Fetched owned Amiibos from Firestore: \(owned.count)")
                    } else {
                        if !self.hasReceivedFirestoreData {
                            print("⏳ Waiting for initial Firestore data... not clearing.")
                            // Avoid clearing if Firestore hasn't returned ownedAmiibos yet
                        } else {
                            print("❌ Firestore returned no ownedAmiibos. Clearing.")
                            self.service.ownedAmiiboIDs = []
                        }
                    }
                    
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    self.isUpdatingFromFirestore = false
                }
            }
    }
}
