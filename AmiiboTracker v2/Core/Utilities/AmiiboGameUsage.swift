//
//  AmiiboGameUsage.swift
//  AmiiboTracker v2
//
//  Updated by Sam Stanwell on 20/07/2025.
//

import Foundation

// MARK: - Detailed Usage Structures

struct AmiiboUsage: Codable, Hashable {
    let usage: String
    let write: Bool

    enum CodingKeys: String, CodingKey {
        case usage = "Usage"
        case write
    }
}


// Represents detailed usage of an amiibo in a specific game
struct AmiiboGameUsage: Codable, Hashable {
    let gameName: String
    let gameID: [String]
    let amiiboUsage: [AmiiboUsage]
}

// Groups full game usage data by platform for a single amiibo
struct AmiiboGames: Codable {
    let gamesSwitch: [AmiiboGameUsage]
    let games3DS: [AmiiboGameUsage]
    let gamesWiiU: [AmiiboGameUsage]


    enum CodingKeys: String, CodingKey {
        case games3DS = "3DS"
        case gamesWiiU = "WiiU"
        case gamesSwitch = "Switch"
    }
}

// Represents the full JSON data for one amiibo including metadata
struct AmiiboData: Codable, Hashable {
    let amiiboSeries: String
    let character: String
    let gameSeries: String
    let head: String
    let tail: String
    let name: String
    let image: String
    let type: String
    let release: [String: String?]?
    let games3DS: [AmiiboGameUsage]
    let gamesWiiU: [AmiiboGameUsage]
    let gamesSwitch: [AmiiboGameUsage]
}

// MARK: - Compact Usage Model (for simpler presentation or legacy data)

struct CompactAmiiboGameUsage: Codable, Hashable {
    let name: String
    let usage: String
}

struct CompactAmiiboGamePlatformUsage: Codable, Hashable {
    let n3ds: [CompactAmiiboGameUsage]?
    let wiiu: [CompactAmiiboGameUsage]?
    let switchGames: [CompactAmiiboGameUsage]?

    enum CodingKeys: String, CodingKey {
        case n3ds = "3DS"
        case wiiu = "WiiU"
        case switchGames = "Switch"
    }
}

struct CompactAmiiboGames: Codable, Hashable {
    let games: CompactAmiiboGamePlatformUsage
}

// Used in aggregate for simpler usage display
struct GameUsage: Hashable {
    let name: String
    let usage: [String]
}

// Wrapper for mapping compact usage to amiibo ID
struct GamesInfoCompact: Codable {
    let amiibos: [String: CompactAmiiboGames]
}

// MARK: - Manual Entries for Missing Amiibo

struct MissingAmiibo {
    let name: String
    let head: String
    let tail: String
    let games3DS: [GameUsage]
    let gamesWiiU: [GameUsage]
    let gamesSwitch: [GameUsage]

    struct GameUsage {
        let name: String
        let usage: [String]
    }

    static let all: [MissingAmiibo] = [
        MissingAmiibo(
            name: "Dark Hammer Slam Bowser",
            head: "00000000",
            tail: "00000000",
            games3DS: [],
            gamesWiiU: [],
            gamesSwitch: [
                GameUsage(
                    name: "Super Mario 3D World + Bowser's Fury",
                    usage: ["Make Fury Bowser appear in Bowser's Fury mode"]
                )
            ]
        )
        // Add more missing manually if needed
    ]
}

extension MissingAmiibo {
    static func injectIntoService(_ service: AmiiboService) {
        for missing in MissingAmiibo.all {
            // Convert MissingAmiibo to AmiiboData if needed or directly inject
            // For example, create AmiiboData on the fly or store static data somewhere else
            let amiiboData = AmiiboData(
                amiiboSeries: "Skylanders SuperChargers",  // example static or pass as needed
                character: "Bowser",
                gameSeries: "Skylanders",
                head: missing.head,
                tail: missing.tail,
                name: missing.name,
                image: "", // or provide image URL/path
                type: "",
                release: nil,
                games3DS: convertGameUsage(missing.games3DS),
                gamesWiiU: convertGameUsage(missing.gamesWiiU),
                gamesSwitch: convertGameUsage(missing.gamesSwitch)
            )

            if !service.amiibos.contains(where: { $0.head == amiiboData.head && $0.tail == amiiboData.tail }) {
                service.amiibos.append(amiiboData)
            }

            service.usageInfo[amiiboData.head + amiiboData.tail] = AmiiboGames(
                gamesSwitch: convertGameUsage(missing.gamesSwitch),
                games3DS: convertGameUsage(missing.games3DS),
                gamesWiiU: convertGameUsage(missing.gamesWiiU)
            )
        }
    }

    private static func convertGameUsage(_ games: [GameUsage]) -> [AmiiboGameUsage] {
        games.map { game in
            AmiiboGameUsage(
                gameName: game.name,
                gameID: [],
                amiiboUsage: game.usage.map { AmiiboUsage(usage: $0, write: false) }
            )
        }
    }
}
