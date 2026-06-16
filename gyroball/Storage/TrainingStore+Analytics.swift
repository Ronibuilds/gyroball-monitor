import Foundation

// Analytics computed over the already-loaded `days` (no extra SQL). All value
// types are Hashable so SwiftUI can diff them cheaply.

struct DayPoint: Hashable { let date: Date; let avgRPM: Double }

struct RPMTrend: Hashable {
    let points: [DayPoint]
    let slopePerWeek: Double      // least-squares RPM change per week
    let deltaVsPrior: Double      // this-week avg minus prior-week avg
}

struct DatedValue: Hashable { let value: Double; let date: Date }

struct PRs: Hashable {
    var topRPM: DatedValue?
    var bestSetAvgRPM: DatedValue?
    var longestArmHold: DatedValue?
    var mostVolumeDay: DatedValue?
    var mostSetsDay: DatedValue?
}

struct WeekSummary: Hashable, Identifiable {
    let weekStart: Date
    let avgRPM: Double
    let spinSeconds: TimeInterval
    let setsCompleted: Int
    let daysTrained: Int
    let goalMetDays: Int
    var id: Date { weekStart }
}

struct ArmBalance: Hashable {
    let armASeconds: TimeInterval
    let armBSeconds: TimeInterval
    let armAAvgRPM: Double
    let armBAvgRPM: Double
    let timeSharePctA: Double      // 0...1
    let rpmAsymmetryPct: Double    // |a-b| / max
    let mostImbalancedDay: Date?
}

struct RPMBin: Hashable, Identifiable {
    let lo: Double
    let hi: Double
    let count: Int
    var id: Double { lo }
    var center: Double { (lo + hi) / 2 }
}

extension TrainingStore {

    private var cal: Calendar { Calendar.current }

    // MARK: - Baseline RPM trend

    func rpmTrend(days n: Int = 42) -> RPMTrend {
        let pts = recentDays(n).filter { $0.avgRPM > 0 }
            .map { DayPoint(date: $0.date, avgRPM: $0.avgRPM) }
        guard pts.count >= 2 else { return RPMTrend(points: pts, slopePerWeek: 0, deltaVsPrior: 0) }

        // Least-squares slope over day index.
        let xs = pts.enumerated().map { Double($0.offset) }
        let ys = pts.map(\.avgRPM)
        let mx = xs.reduce(0,+) / Double(xs.count)
        let my = ys.reduce(0,+) / Double(ys.count)
        var num = 0.0, den = 0.0
        for i in xs.indices { num += (xs[i]-mx)*(ys[i]-my); den += (xs[i]-mx)*(xs[i]-mx) }
        let slopePerDay = den > 0 ? num/den : 0

        // This week vs prior week average.
        let now = cal.startOfDay(for: Date())
        func weekAvg(_ offset: Int) -> Double {
            let lo = cal.date(byAdding: .day, value: -7*(offset+1)+1, to: now)!
            let hi = cal.date(byAdding: .day, value: -7*offset, to: now)!
            let vals = pts.filter { $0.date >= cal.startOfDay(for: lo) && $0.date <= cal.startOfDay(for: hi) }.map(\.avgRPM)
            return vals.isEmpty ? 0 : vals.reduce(0,+)/Double(vals.count)
        }
        let thisW = weekAvg(0), priorW = weekAvg(1)
        let delta = (thisW > 0 && priorW > 0) ? thisW - priorW : 0
        return RPMTrend(points: pts, slopePerWeek: slopePerDay*7, deltaVsPrior: delta)
    }

    // MARK: - Weekly summaries

    func weekSummaries(weeks n: Int = 8, default goal: Goal) -> [WeekSummary] {
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
        var out: [WeekSummary] = []
        for w in (0..<n).reversed() {
            guard let start = cal.date(byAdding: .weekOfYear, value: -w, to: thisWeek),
                  let end = cal.date(byAdding: .weekOfYear, value: 1, to: start) else { continue }
            let wd = days.filter { $0.date >= start && $0.date < end }
            let secs = wd.reduce(0) { $0 + $1.spinSeconds }
            let avg: Double = {
                let total = secs
                guard total > 0 else { return 0 }
                return wd.reduce(0) { $0 + $1.avgRPM * $1.spinSeconds } / total
            }()
            out.append(WeekSummary(
                weekStart: start, avgRPM: avg, spinSeconds: secs,
                setsCompleted: wd.reduce(0) { $0 + $1.completedSets },
                daysTrained: wd.filter { !$0.sets.isEmpty }.count,
                goalMetDays: wd.filter { $0.completion(default: goal) >= 1 }.count))
        }
        return out
    }

    var weeklyVolumeDelta: Double {
        let s = weekSummaries(weeks: 2, default: .default)
        guard s.count == 2, s[0].spinSeconds > 0 else { return 0 }
        return (s[1].spinSeconds - s[0].spinSeconds) / s[0].spinSeconds
    }

    // MARK: - Personal records

    func personalRecords() -> PRs {
        var prs = PRs()
        func better(_ cur: DatedValue?, _ v: Double, _ d: Date) -> DatedValue? {
            (cur == nil || v > cur!.value) ? DatedValue(value: v, date: d) : cur
        }
        for day in days {
            if day.spinSeconds > 0 { prs.mostVolumeDay = better(prs.mostVolumeDay, day.spinSeconds, day.date) }
            if day.completedSets > 0 { prs.mostSetsDay = better(prs.mostSetsDay, Double(day.completedSets), day.date) }
            for set in day.sets {
                if set.avgRPM > 0 { prs.bestSetAvgRPM = better(prs.bestSetAvgRPM, set.avgRPM, day.date) }
                for arm in set.arms {
                    if arm.topRPM > 0 { prs.topRPM = better(prs.topRPM, arm.topRPM, day.date) }
                    if arm.spinSeconds > 0 { prs.longestArmHold = better(prs.longestArmHold, arm.spinSeconds, day.date) }
                }
            }
        }
        return prs
    }

    // MARK: - Consistency

    func longestStreak(default goal: Goal) -> Int {
        let met = days.filter { $0.completion(default: goal) >= 1 }.map(\.date).sorted()
        guard !met.isEmpty else { return 0 }
        var best = 1, run = 1
        for i in 1..<met.count {
            if let prev = cal.date(byAdding: .day, value: 1, to: met[i-1]), prev == met[i] {
                run += 1; best = max(best, run)
            } else { run = 1 }
        }
        return best
    }

    func adherenceRate(days n: Int = 30, default goal: Goal) -> Double {
        let recent = recentDays(n)
        guard !recent.isEmpty else { return 0 }
        let met = recent.filter { $0.completion(default: goal) >= 1 }.count
        return Double(met) / Double(recent.count)
    }

    // MARK: - Per-arm balance

    func armBalance(days n: Int = 14) -> ArmBalance {
        var a0 = 0.0, a1 = 0.0, r0 = 0.0, r1 = 0.0
        var worstDay: Date?; var worstSkew = 0.0
        for day in recentDays(n) where !day.sets.isEmpty {
            var d0 = 0.0, d1 = 0.0
            for set in day.sets {
                if set.arms.count >= 2 {
                    a0 += set.arms[0].spinSeconds; a1 += set.arms[1].spinSeconds
                    d0 += set.arms[0].spinSeconds; d1 += set.arms[1].spinSeconds
                    r0 += set.arms[0].avgRPM * set.arms[0].spinSeconds
                    r1 += set.arms[1].avgRPM * set.arms[1].spinSeconds
                }
            }
            let tot = d0 + d1
            if tot > 0 {
                let skew = abs(d0 - d1) / tot
                if skew > worstSkew { worstSkew = skew; worstDay = day.date }
            }
        }
        let totalTime = a0 + a1
        let avgA = a0 > 0 ? r0/a0 : 0, avgB = a1 > 0 ? r1/a1 : 0
        let maxAvg = Swift.max(avgA, avgB)
        return ArmBalance(
            armASeconds: a0, armBSeconds: a1, armAAvgRPM: avgA, armBAvgRPM: avgB,
            timeSharePctA: totalTime > 0 ? a0/totalTime : 0.5,
            rpmAsymmetryPct: maxAvg > 0 ? abs(avgA-avgB)/maxAvg : 0,
            mostImbalancedDay: worstDay)
    }

    // MARK: - RPM distribution

    func avgRPMDistribution(binWidth: Double = 150) -> [RPMBin] {
        let vals = days.flatMap { $0.sets }.map(\.avgRPM).filter { $0 > 0 }
        guard !vals.isEmpty else { return [] }
        let lo = (vals.min()! / binWidth).rounded(.down) * binWidth
        let hi = (vals.max()! / binWidth).rounded(.up) * binWidth
        var bins: [RPMBin] = []
        var x = lo
        while x < hi {
            let c = vals.filter { $0 >= x && $0 < x + binWidth }.count
            bins.append(RPMBin(lo: x, hi: x + binWidth, count: c))
            x += binWidth
        }
        return bins
    }
}
