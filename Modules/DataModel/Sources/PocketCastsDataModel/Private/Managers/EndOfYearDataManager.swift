import FMDB
import PocketCastsUtils

/// Calculates user End of Year stats
class EndOfYearDataManager {
    private let endPeriod = "2022-12-01"

    /// Returns the approximate listening time for the current year
    func listeningTime(dbQueue: FMDatabaseQueue) -> Double? {
        var listeningTime: Double?

        dbQueue.inDatabase { db in
            do {
                let query = "SELECT SUM(playedUpTo) as totalPlayedTime from \(DataManager.episodeTableName) WHERE lastPlaybackInteractionDate IS NOT NULL AND lastPlaybackInteractionDate BETWEEN strftime('%s', '2022-01-01') and strftime('%s', '\(endPeriod)')"
                let resultSet = try db.executeQuery(query, values: nil)
                defer { resultSet.close() }

                if resultSet.next() {
                    listeningTime = resultSet.double(forColumn: "totalPlayedTime")
                }
            } catch {
                FileLog.shared.addMessage("PodcastDataManager.listeningTime error: \(error)")
            }
        }

        return listeningTime
    }

    /// Returns all the categories the user has listened to podcasts
    ///
    /// The returned array is ordered from the most listened to the least
    func listenedCategories(dbQueue: FMDatabaseQueue) -> [ListenedCategory] {
        var listenedCategories: [ListenedCategory] = []

        dbQueue.inDatabase { db in
            do {
                let query = """
                            SELECT COUNT(DISTINCT podcastUuid) as numberOfPodcasts,
                                SUM(playedUpTo) as totalPlayedTime,
                                replace(IFNULL( nullif(substr(\(DataManager.podcastTableName).podcastCategory, 0, INSTR(\(DataManager.podcastTableName).podcastCategory, char(10))), '') , \(DataManager.podcastTableName).podcastCategory), CHAR(10), '') as category
                            FROM \(DataManager.episodeTableName), \(DataManager.podcastTableName)
                            WHERE \(DataManager.podcastTableName).uuid = \(DataManager.episodeTableName).podcastUuid and
                                lastPlaybackInteractionDate IS NOT NULL AND
                                lastPlaybackInteractionDate BETWEEN strftime('%s', '2022-01-01') and strftime('%s', '\(endPeriod)')
                            GROUP BY category
                            ORDER BY totalPlayedTime DESC
"""

                let resultSet = try db.executeQuery(query, values: nil)
                defer { resultSet.close() }

                while resultSet.next() {
                    let numberOfPodcasts = Int(resultSet.int(forColumn: "numberOfPodcasts"))
                    if let categoryTitle = resultSet.string(forColumn: "category") {
                        listenedCategories.append(ListenedCategory(numberOfPodcasts: numberOfPodcasts, categoryTitle: categoryTitle))
                    }
                }
            } catch {
                FileLog.shared.addMessage("PodcastDataManager.listenedCategories error: \(error)")
            }
        }

        return listenedCategories
    }

}

public struct ListenedCategory {
    public let numberOfPodcasts: Int
    public let categoryTitle: String
}