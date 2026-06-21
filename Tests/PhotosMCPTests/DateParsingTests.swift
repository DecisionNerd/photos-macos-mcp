import Testing
@testable import PhotosMCP

struct DateParsingTests {

    @Test("parse ISO 8601 datetime")
    func parseISO8601() {
        let d = DateParsing.parse("2024-01-15T14:30:00Z")
        #expect(d != nil)
        #expect(abs(d!.timeIntervalSince1970 - 1_705_329_000) < 0.001)
    }

    @Test("parse date-only yyyy-MM-dd")
    func parseDateOnly() {
        let d = DateParsing.parse("2024-06-20")
        #expect(d != nil)
        #expect(abs(d!.timeIntervalSince1970 - 1_718_841_600) < 0.001)
    }

    @Test("parse empty string returns nil")
    func parseEmpty() {
        #expect(DateParsing.parse("") == nil)
        #expect(DateParsing.parse("   ") == nil)
    }

    @Test("parse invalid string returns nil")
    func parseInvalid() {
        #expect(DateParsing.parse("not-a-date") == nil)
        #expect(DateParsing.parse("invalid") == nil)
    }

    @Test("parseEndOfDay returns end of same day")
    func parseEndOfDay() {
        let d = DateParsing.parseEndOfDay("2024-01-15")
        #expect(d != nil)
        #expect(abs(d!.timeIntervalSince1970 - 1_705_363_199.999) < 0.001)
    }

    @Test("parseEndOfDay with invalid string returns nil")
    func parseEndOfDayInvalid() {
        #expect(DateParsing.parseEndOfDay("") == nil)
        #expect(DateParsing.parseEndOfDay("invalid") == nil)
    }
}
