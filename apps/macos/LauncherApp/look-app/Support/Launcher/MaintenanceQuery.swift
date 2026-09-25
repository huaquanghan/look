import Foundation

/// Typo-tolerant, whole-word matching for the maintenance rows pinned to the
/// top of results ("Empty Trash", "Clear Font Cache"). Deliberately narrower
/// than the fuzzy subsequence scorer used elsewhere in the launcher: a query
/// matches only when its words line up with a known phrase word-for-word, so
/// `clean` or `font` alone never outranks an app like CleanMyMac or Font Book.
enum MaintenanceQuery {
    enum Action: Equatable {
        case emptyTrash
        case clearFontCache
    }

    /// Canonical word sequences that select each action. A query matches a
    /// phrase when it has the same word count and every word lines up: exact,
    /// or - for words of 5+ letters - a single-edit typo (substitution,
    /// insertion, deletion, or an adjacent-letter swap); the LAST word of a
    /// multi-word phrase may also just be a prefix (`clean font ca`).
    /// One-word phrases skip the prefix rule entirely, so a partial word like
    /// `emp` never pins the row - only `empty`/`trash` themselves (typos
    /// included) do.
    private static let phrases: [(words: [String], action: Action)] = [
        (["empty"], .emptyTrash),
        (["trash"], .emptyTrash),
        (["empty", "trash"], .emptyTrash),
        (["clean", "trash"], .emptyTrash),
        (["clear", "trash"], .emptyTrash),
        (["font", "cache"], .clearFontCache),
        (["fonts", "cache"], .clearFontCache),
        (["reset", "fonts"], .clearFontCache),
        (["clear", "font", "cache"], .clearFontCache),
        (["clean", "font", "cache"], .clearFontCache),
    ]

    static func match(_ query: String) -> Action? {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }
        for phrase in phrases where phrase.words.count == words.count {
            if matches(words: words, phrase: phrase.words) {
                return phrase.action
            }
        }
        return nil
    }

    private static func matches(words: [String], phrase: [String]) -> Bool {
        for (index, word) in words.enumerated() {
            let canonical = phrase[index]
            if word == canonical { continue }
            let isLast = index == words.count - 1
            // Multi-word phrases only: the last word may be typed as a prefix.
            if phrase.count > 1, isLast, !word.isEmpty, canonical.hasPrefix(word) { continue }
            if canonical.count >= 5, isNearTypo(word, canonical) { continue }
            return false
        }
        return true
    }

    /// True when `a` is one edit (substitution, insertion, deletion, or an
    /// adjacent-character swap) away from `b`. Hand-rolled rather than a DP
    /// table since the bound is fixed at 1.
    private static func isNearTypo(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let la = Array(a), lb = Array(b)

        if la.count == lb.count {
            var diffIndices: [Int] = []
            for i in 0..<la.count where la[i] != lb[i] { diffIndices.append(i) }
            if diffIndices.count == 1 { return true }
            if diffIndices.count == 2, diffIndices[1] == diffIndices[0] + 1,
                la[diffIndices[0]] == lb[diffIndices[1]], la[diffIndices[1]] == lb[diffIndices[0]] {
                return true
            }
            return false
        }

        guard abs(la.count - lb.count) == 1 else { return false }
        let (short, long) = la.count < lb.count ? (la, lb) : (lb, la)
        var i = 0, j = 0, usedSkip = false
        while i < short.count && j < long.count {
            if short[i] == long[j] {
                i += 1
                j += 1
            } else {
                if usedSkip { return false }
                usedSkip = true
                j += 1
            }
        }
        return true
    }
}
