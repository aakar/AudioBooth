import AppIntents
import Foundation

struct AddBookmarkIntent: AppIntent {
  static let title: LocalizedStringResource = "Add a bookmark"
  static let description = IntentDescription(
    "Adds a bookmark at the current position in the playing audiobook."
  )
  static let openAppWhenRun = false

  @Parameter(
    title: "Content",
    description: "The bookmark title",
    requestValueDialog: "What should the bookmark be called?"
  )
  var content: String?

  static var parameterSummary: some ParameterSummary {
    Summary("Add bookmark \(\.$content)")
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let (bookID, bookTitle, time) = try await MainActor.run {
      let playerManager = PlayerManager.shared

      guard let currentPlayer = playerManager.current as? BookPlayerModel else {
        throw AppIntentError.noAudiobookPlaying
      }

      // A book can be the "current" player while only loaded (restored at
      // launch) or paused, in which case `current` is non-nil but nothing is
      // actually playing. Require active playback so the shortcut doesn't
      // silently create a bookmark at a stale position.
      guard currentPlayer.isPlaying else {
        throw AppIntentError.noAudiobookPlaying
      }

      guard let time = currentPlayer.getCurrentTime() else {
        throw AppIntentError.noAudiobookPlaying
      }

      return (currentPlayer.id, currentPlayer.title, time)
    }

    let title = content ?? "Bookmark"

    _ = try await BookmarkSyncQueue.shared.create(
      bookID: bookID,
      title: title,
      time: time
    )

    return .result(dialog: "Bookmark added to \(bookTitle)")
  }
}
