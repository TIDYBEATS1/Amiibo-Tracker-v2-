import Foundation

struct Amiibo: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let series: String
    let character: String
    let imageURL: URL?
    var isOwned: Bool = false
    let gameSeries: String?
    let type: String
    let release: ReleaseDates?
    let head: String
    let tail: String
    let releaseDate: Date? = nil

    
    enum CodingKeys: String, CodingKey {
        case name
        case series = "amiiboSeries"
        case character
        case gameSeries
        case image = "image"
        case head
        case tail
        case type
        case release
    }
    
    struct ReleaseDates: Codable, Equatable, Hashable {
        let au: String?
        let eu: String?
        let jp: String?
        let na: String?
    }
    init(
        id: String,
        name: String,
        series: String,
        character: String,
        imageURL: URL?,
        isOwned: Bool = false,
        gameSeries: String?,
        type: String,
        release: ReleaseDates?,
        head: String,
        tail: String
    ) {
        self.id = id
        self.name = name
        self.series = series
        self.character = character
        self.imageURL = imageURL
        self.isOwned = isOwned
        self.gameSeries = gameSeries
        self.type = type
        self.release = release
        self.head = head
        self.tail = tail
    }
    // MARK: - Decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        series = try container.decode(String.self, forKey: .series)
        character = try container.decode(String.self, forKey: .character)
        gameSeries = try container.decodeIfPresent(String.self, forKey: .gameSeries)
        
        let imageString = try container.decode(String.self, forKey: .image)
        imageURL = URL(string: imageString)
        
        type = try container.decode(String.self, forKey: .type)
        release = try container.decodeIfPresent(ReleaseDates.self, forKey: .release)
        
        head = try container.decode(String.self, forKey: .head)
        tail = try container.decode(String.self, forKey: .tail)
        id = head + tail
        
        isOwned = false
    }
    
    // MARK: - Encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(name, forKey: .name)
        try container.encode(series, forKey: .series)
        try container.encode(character, forKey: .character)
        try container.encodeIfPresent(gameSeries, forKey: .gameSeries)
        try container.encode(imageURL?.absoluteString ?? "", forKey: .image)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(release, forKey: .release)
        
        // Split id into head & tail (head first 8 chars, tail remainder)
        let head = String(id.prefix(8))
        let tail = String(id.dropFirst(8))
        
        try container.encode(head, forKey: .head)
        try container.encode(tail, forKey: .tail)
    }
}

extension Amiibo {
    var localImageFilename: String {
        "\(id).png"
    }
    
    var localImageURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("amiibo_images").appendingPathComponent(localImageFilename)
    }
}

struct AmiiboResponse: Codable {
    let amiibo: [Amiibo]
}


