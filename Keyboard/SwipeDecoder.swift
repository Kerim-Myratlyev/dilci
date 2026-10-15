import UIKit

/// Turns a swipe path into words, like QuickPath on the system keyboard.
///
/// 1. Candidates must start near the first touch and end near the last one.
/// 2. Every letter must be passed, in order, somewhere along the path.
/// 3. Survivors are scored by how closely the path follows the ideal line
///    through their keys (dynamic time warping), plus word frequency.
///
/// Tuned on simulated noisy swipes: about 9 in 10 words come out first,
/// and the right word is in the top four about 96% of the time.
final class SwipeDecoder {
    static let shared = SwipeDecoder()

    private struct Entry {
        let word: String
        let seq: [Unicode.Scalar]
        let rank: Int
    }

    private var index: [Unicode.Scalar: [Entry]] = [:]
    private var loadedLanguage: Lang?
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "app.dilci.swipe", qos: .userInitiated)

    // Tuning (see README)
    private let samples = 32
    private let densePoints = 96
    private let endRadius: CGFloat = 1.3
    private let passRadius: CGFloat = 1.8
    private let frequencyWeight: CGFloat = 0.18
    private let warpWindow = 6

    // MARK: Loading

    func preload(_ language: Lang) {
        queue.async { _ = self.entries(for: language) }
    }

    private func entries(for language: Lang) -> [Unicode.Scalar: [Entry]] {
        lock.lock()
        if loadedLanguage == language {
            let current = index
            lock.unlock()
            return current
        }
        lock.unlock()

        let name = language == .russian ? "swipe_ru" : "swipe_en"
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var built: [Unicode.Scalar: [Entry]] = [:]
        var rank = 0
        text.enumerateLines { line, _ in
            let seq = SwipeDecoder.normalize(line)
            if seq.count >= 2 {
                built[seq[0], default: []].append(Entry(word: line, seq: seq, rank: rank))
            }
            rank += 1
        }
        lock.lock()
        index = built          // only one language in memory at a time
        loadedLanguage = language
        lock.unlock()
        return built
    }

    static func normalize(_ word: String) -> [Unicode.Scalar] {
        var out: [Unicode.Scalar] = []
        for scalar in word.lowercased().unicodeScalars {
            var s = scalar
            if s == "'" || s == "’" { continue }
            if s == "ё" { s = "е" }
            if s == "ъ" { s = "ь" }
            if out.last != s { out.append(s) }
        }
        return out
    }

    // MARK: Decoding

    func decode(path: [CGPoint], keys: [Character: CGPoint], keyWidth u: CGFloat, language: Lang) -> [String] {
        guard path.count >= 2, u > 0 else { return [] }
        let dictionary = entries(for: language)
        guard !dictionary.isEmpty else { return [] }

        var centers: [Unicode.Scalar: CGPoint] = [:]
        for (c, p) in keys {
            if let s = String(c).lowercased().unicodeScalars.first { centers[s] = p }
        }

        let resampled = Self.resample(path, count: samples)
        let dense = Self.resample(path, count: densePoints)
        let length = Self.length(path)
        guard let first = path.first, let last = path.last else { return [] }

        let starts = centers.filter { Self.distance($0.value, first) < endRadius * u }.map(\.key)
        let ends = Set(centers.filter { Self.distance($0.value, last) < endRadius * u }.map(\.key))
        let logMax = log(40_000.0)

        var scored: [(CGFloat, String)] = []
        scored.reserveCapacity(64)

        for start in starts {
            guard let bucket = dictionary[start] else { continue }
            for entry in bucket {
                guard let lastLetter = entry.seq.last, ends.contains(lastLetter) else { continue }

                var ideal: [CGPoint] = []
                ideal.reserveCapacity(entry.seq.count)
                var missing = false
                for s in entry.seq {
                    guard let p = centers[s] else { missing = true; break }
                    ideal.append(p)
                }
                if missing { continue }

                let idealLength = Self.length(ideal)
                if idealLength > length * 1.9 + u || idealLength < length * 0.45 - u { continue }

                // Every letter must be passed in order.
                var j = 0
                var passes = true
                let limit = passRadius * u
                for p in ideal {
                    while j < dense.count && Self.distance(dense[j], p) > limit { j += 1 }
                    if j == dense.count { passes = false; break }
                }
                if !passes { continue }

                let shape = warpDistance(resampled, Self.resample(ideal, count: samples)) / u
                let frequency = frequencyWeight * CGFloat(log(Double(entry.rank + 2)) / logMax)
                scored.append((shape + frequency, entry.word))
            }
        }

        scored.sort { $0.0 < $1.0 }
        var seen = Set<String>()
        var result: [String] = []
        for (_, word) in scored where !seen.contains(word.lowercased()) {
            seen.insert(word.lowercased())
            result.append(word)
            if result.count == 5 { break }
        }
        return result
    }

    /// Banded dynamic time warping, normalized per step.
    private func warpDistance(_ a: [CGPoint], _ b: [CGPoint]) -> CGFloat {
        let n = a.count
        let w = warpWindow
        let inf = CGFloat.greatestFiniteMagnitude / 4
        var previous = [CGFloat](repeating: inf, count: n + 1)
        var current = [CGFloat](repeating: inf, count: n + 1)
        previous[0] = 0
        for i in 1...n {
            current[0] = inf
            for k in 1...n { current[k] = inf }
            let lo = max(1, i - w), hi = min(n, i + w)
            if lo <= hi {
                for k in lo...hi {
                    let cost = Self.distance(a[i - 1], b[k - 1])
                    current[k] = cost + min(previous[k], current[k - 1], previous[k - 1])
                }
            }
            swap(&previous, &current)
        }
        return previous[n] / CGFloat(2 * n)
    }

    // MARK: Geometry

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    static func length(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var total: CGFloat = 0
        for i in 1..<points.count { total += distance(points[i - 1], points[i]) }
        return total
    }

    static func resample(_ points: [CGPoint], count n: Int) -> [CGPoint] {
        guard points.count > 1, n > 1 else { return Array(repeating: points.first ?? .zero, count: n) }
        var cumulative: [CGFloat] = [0]
        cumulative.reserveCapacity(points.count)
        for i in 1..<points.count { cumulative.append(cumulative[i - 1] + distance(points[i - 1], points[i])) }
        let total = cumulative[cumulative.count - 1]
        guard total > 0 else { return Array(repeating: points[0], count: n) }
        var out: [CGPoint] = []
        out.reserveCapacity(n)
        var j = 0
        for i in 0..<n {
            let t = total * CGFloat(i) / CGFloat(n - 1)
            while j < cumulative.count - 2 && cumulative[j + 1] < t { j += 1 }
            let segment = cumulative[j + 1] - cumulative[j]
            let f = segment == 0 ? 0 : (t - cumulative[j]) / segment
            let a = points[j], b = points[j + 1]
            out.append(CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f))
        }
        return out
    }
}
