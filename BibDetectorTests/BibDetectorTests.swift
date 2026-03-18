//
//  BibDetectorTests.swift
//  BibDetectorTests
//
//  Created by Alex Rabin on 3/16/26.
//

import Testing
@testable import BibDetector

struct BibDetectorTests {

    @Test func bibParserNormalizesDigitsOnlyValues() async throws {
        #expect(BibParser.normalizedBibCandidate(from: "bib 101") == "101")
        #expect(BibParser.normalizedBibCandidate(from: "A-00450") == "00450")
        #expect(BibParser.normalizedBibCandidate(from: "x") == nil)
        #expect(BibParser.normalizedBibCandidate(from: "123456") == nil)
    }

    @Test func repositoryMatchesWithLeadingZeroFallback() async throws {
        let repository = await RunnerRepository(
            runners: [
                RunnerProfile(bibNumber: "101", name: "Jordan Alvarez", nickname: "Jordy")
            ]
        )

        await #expect(repository.matchRunner(bibNumber: "101")?.displayName == "Jordy")
        await #expect(repository.matchRunner(bibNumber: "00101")?.displayName == "Jordy")
        #expect(repository.matchRunner(bibNumber: "999") == nil)
    }

}
