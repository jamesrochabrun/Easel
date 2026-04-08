import Foundation

struct RelativeMessageTimeFormatter {
  func string(from date: Date, now: Date = Date()) -> String {
    let elapsed = max(0, now.timeIntervalSince(date))

    if elapsed < 10 {
      return "now"
    }

    if elapsed < 60 {
      return "\(Int(elapsed)) sec ago"
    }

    if elapsed < 3600 {
      let minutes = Int(elapsed / 60)
      return "\(minutes) min ago"
    }

    if elapsed < 86_400 {
      let hours = Int(elapsed / 3600)
      return "\(hours) hr ago"
    }

    let days = Int(elapsed / 86_400)
    return "\(days)d ago"
  }
}
