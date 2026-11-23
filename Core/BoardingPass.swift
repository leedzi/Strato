import Foundation

/// Text for the boarding pass barcode, laid out as an IATA Bar Coded Boarding Pass (BCBP, Resolution 792)
/// single-leg "M1" record, so a real boarding-pass scanner decodes the route, flight, date and seat.
enum BoardingPassCode {
    private static func pad(_ s: String, _ n: Int) -> String {
        let cleaned = String(s.uppercased().unicodeScalars.filter { $0.value >= 32 && $0.value < 127 }.map(Character.init))
        if cleaned.count >= n { return String(cleaned.prefix(n)) }
        return cleaned + String(repeating: " ", count: n - cleaned.count)
    }

    /// "CA1831" -> ("CA", "1831", ""), "MU583A" -> ("MU", "583", "A").
    static func split(flightNumber: String) -> (carrier: String, number: String, suffix: String) {
        let s = Array(flightNumber.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
        guard s.count >= 3 else { return (String(s), "", "") }
        // Carrier designators are two characters (one may be a digit) or three letters.
        var carrierLength = 2
        if s.count > 3, s[0].isLetter, s[1].isLetter, s[2].isLetter { carrierLength = 3 }
        let carrier = String(s.prefix(carrierLength))
        var rest = Array(s.dropFirst(carrierLength))
        var suffix = ""
        if let last = rest.last, last.isLetter, rest.dropLast().allSatisfy({ $0.isNumber }) {
            suffix = String(last)
            rest.removeLast()
        }
        let digits = String(rest.filter { $0.isNumber })
        return (carrier, digits, suffix)
    }

    /// "12A" -> "012A".
    static func seatField(_ seat: String) -> String {
        let s = seat.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        let digits = s.filter { $0.isNumber }
        let letter = s.filter { $0.isLetter }.prefix(1)
        guard let row = Int(digits) else { return pad(String(s), 4) }
        return String(format: "%03d", min(row, 999)) + (letter.isEmpty ? " " : String(letter))
    }

    static func julianDay(_ date: Date, calendar: Calendar) -> Int {
        calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    static func make(
        passenger: String,
        pnr: String,
        fromIATA: String,
        toIATA: String,
        flightNumber: String,
        date: Date,
        cabin: CabinClass,
        seat: String,
        sequence: Int,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> String {
        let f = split(flightNumber: flightNumber)
        let number = String(format: "%04d", min(Int(f.number) ?? 0, 9999)) + (f.suffix.isEmpty ? " " : f.suffix)
        var out = "M1"
        out += pad(passenger, 20)
        out += "E"
        out += pad(pnr, 7)
        out += pad(fromIATA, 3)
        out += pad(toIATA, 3)
        out += pad(f.carrier, 3)
        out += number
        out += String(format: "%03d", julianDay(date, calendar: calendar))
        out += cabin.code
        out += seatField(seat)
        out += String(format: "%04d", min(max(sequence, 0), 9999)) + " "
        out += "1"
        out += "00"
        return out
    }

    /// A booking-reference-looking code that is stable for a given session.
    static func pnr(for id: UUID) -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var h = UInt64(truncatingIfNeeded: id.uuidString.hashValueStable)
        var out = ""
        for _ in 0..<6 {
            out.append(alphabet[Int(h % UInt64(alphabet.count))])
            h /= UInt64(alphabet.count)
        }
        return out
    }
}

/// Seat and gate assignment helpers.
enum Seating {
    static func letters(for cabin: CabinClass) -> [String] {
        switch cabin {
        case .first: return ["A", "K"]
        case .business: return ["A", "D", "G", "K"]
        case .premium: return ["A", "C", "D", "G", "H", "K"]
        case .economy: return ["A", "B", "C", "H", "J", "K"]
        }
    }

    static func rows(for cabin: CabinClass) -> ClosedRange<Int> {
        switch cabin {
        case .first: return 1...4
        case .business: return 6...18
        case .premium: return 21...28
        case .economy: return 31...68
        }
    }

    static func isWindow(_ seat: String) -> Bool {
        guard let last = seat.last else { return false }
        return last == "A" || last == "K"
    }

    /// A window seat, chosen from a seed so tests are deterministic.
    static func windowSeat(cabin: CabinClass, seed: Int) -> String {
        let r = rows(for: cabin)
        let row = r.lowerBound + abs(seed) % r.count
        return "\(row)\(abs(seed / 7) % 2 == 0 ? "A" : "K")"
    }

    static func gate(seed: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "G", "H"]
        return "\(letters[abs(seed) % letters.count])\(1 + abs(seed / 11) % 48)"
    }
}
