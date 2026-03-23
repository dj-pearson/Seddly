import Testing
@testable import Seddly

@Suite("RuleFilterService Tests")
struct RuleFilterServiceTests {
    @Test("Strong commitment language scores high")
    func strongCommitment() {
        let text = "I will have the AC fixed by 3/28. Guaranteed."
        let score = RuleFilterService.score(text: text)
        #expect(score >= 40)
    }

    @Test("Hedging language reduces score")
    func hedgingLanguage() {
        let text = "I'll try to probably get someone out there if possible."
        let score = RuleFilterService.score(text: text)
        #expect(score < 40)
    }

    @Test("Dates and dollar amounts boost score")
    func datesAndDollars() {
        let text = "We will complete the repair for $500 by 4/15."
        let score = RuleFilterService.score(text: text)
        #expect(score >= 50)
    }

    @Test("Irrelevant text scores zero")
    func irrelevantText() {
        let text = "haha that's funny, look at this meme"
        let score = RuleFilterService.score(text: text)
        #expect(score == 0)
    }

    @Test("Score is clamped between 0 and 100")
    func scoreClamping() {
        let weakText = "might maybe hopefully if possible no guarantees probably"
        #expect(RuleFilterService.score(text: weakText) >= 0)

        let strongText = "I will guarantee promise confirmed agreed scheduled for by 3/28 $500 deliver complete finish"
        #expect(RuleFilterService.score(text: strongText) <= 100)
    }
}
