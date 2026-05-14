import Foundation

/// Returns true iff `needle` appears in `haystack` aligned to a word boundary on the LEFT side.
/// "Word boundary" = start of string OR the preceding character is not a letter/digit.
/// The RIGHT side is unconstrained — this lets "bookmark" match "bookmarks" (plurals), which
/// matters for LLM-generated rule titles that often use the singular noun form.
///
/// Callers are expected to lowercase both arguments before calling — comparison is byte-wise
/// on Unicode scalars (handles ASCII and most Latin-extended scripts correctly).
///
/// Performance: O(haystack.count * needle.count) worst case. Strings here are short
/// (AX titles cap at ~80 chars, needles at ~30), so this is fine for hot-path use.
func wordBoundaryContains(haystack: String, needle: String) -> Bool {
    guard !needle.isEmpty, !haystack.isEmpty else { return false }
    if haystack == needle { return true }

    let hay = Array(haystack)
    let need = Array(needle)
    guard need.count <= hay.count else { return false }

    let lastStart = hay.count - need.count
    var i = 0
    while i <= lastStart {
        let leftIsBoundary = (i == 0) || !isWordChar(hay[i - 1])
        if leftIsBoundary {
            var matched = true
            for j in 0..<need.count where hay[i + j] != need[j] {
                matched = false; break
            }
            if matched { return true }
        }
        i += 1
    }
    return false
}

private func isWordChar(_ c: Character) -> Bool {
    c.isLetter || c.isNumber
}
