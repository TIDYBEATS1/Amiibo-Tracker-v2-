extension MissingAmiibo {
    static func injectIntoService(_ service: AmiiboService) {
        for amiibo in MissingAmiibo.all {
            if !(service.amiibos.contains { $0.head == amiibo.head && $0.tail == amiibo.tail }) {
                service.amiibos.append(amiibo)
            }

            let usage = AmiiboGames(
                gamesSwitch: amiibo.gamesSwitchAsStandard,
                games3DS: amiibo.games3DSAsStandard,
                gamesWiiU: amiibo.gamesWiiUAsStandard
            )
            service.usageInfo[amiibo.id] = usage
        }
    }
    
    // Also include this here or separately:
    static func convertToAmiiboGames(from missing: MissingAmiibo) -> AmiiboGames {
        func convertUsages(_ games: [GameUsage]) -> [AmiiboGameUsage] {
            return games.map { game in
                AmiiboGameUsage(
                    gameName: game.name,
                    gameID: [],
                    amiiboUsage: game.usage.map { usageString in
                        AmiiboUsage(usage: usageString, write: false)
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
}
struct MissingAmiibo {
    static let darkHammerSlamBowser = AmiiboData(
        head: "00000000",
        tail: "00000000",
        name: "Dark Hammer Slam Bowser",
        amiiboSeries: "Skylanders SuperChargers",
        character: "Bowser",
        gameSeries: "Skylanders",
        games3DS: [],
        gamesWiiU: [],
        gamesSwitch: [
            AmiiboGameUsage(
                gameName: "Super Mario 3D World + Bowser's Fury",
                amiiboUsage: [
                    AmiiboUsage(usage: "Make Fury Bowser appear in Bowser's Fury mode", write: false)
                ],
                gameID: ["01007EF00399C000"]
            )
        ]
    )


