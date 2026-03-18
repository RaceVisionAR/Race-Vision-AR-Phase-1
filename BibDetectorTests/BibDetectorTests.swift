//
//  BibDetectorTests.swift
//  BibDetectorTests
//
//  Created by Alex Rabin on 3/16/26.
//

import CoreGraphics
import Foundation
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

    @MainActor
    @Test func appModelPromotesVisibleTrackThenFadesAndRemovesIt() async throws {
        let repository = RunnerRepository(
            runners: [
                RunnerProfile(bibNumber: "101", name: "Jordan Alvarez", nickname: "Jordy")
            ]
        )
        let appModel = AppModel(repository: repository)
        let viewSize = CGSize(width: 300, height: 600)
        let boundingBox = CGRect(x: 0.1, y: 0.2, width: 0.25, height: 0.12)
        let baseTime = Date(timeIntervalSinceReferenceDate: 100)

        for offset in stride(from: 0.0, through: 0.4, by: 0.2) {
            appModel.ingestOCRResults(
                [OCRBibResult(bibNumber: "101", confidence: 0.92, boundingBox: boundingBox)],
                viewSize: viewSize,
                now: baseTime.addingTimeInterval(offset)
            )
        }

        #expect(appModel.visibleTracks.count == 1)
        #expect(appModel.trackedOverlays["101"]?.visibilityStatus == .visible)
        #expect(appModel.trackedOverlays["101"]?.runnerProfile?.displayName == "Jordy")

        appModel.ingestOCRResults([], viewSize: viewSize, now: baseTime.addingTimeInterval(1.2))
        #expect(appModel.trackedOverlays["101"]?.visibilityStatus == .visible)

        appModel.ingestOCRResults([], viewSize: viewSize, now: baseTime.addingTimeInterval(1.6))
        #expect(appModel.trackedOverlays["101"]?.visibilityStatus == .fading)

        appModel.ingestOCRResults([], viewSize: viewSize, now: baseTime.addingTimeInterval(1.9))
        #expect(appModel.trackedOverlays["101"] == nil)
    }

    @MainActor
    @Test func appModelAppliesConfidenceFloorAndCardCap() async throws {
        let appModel = AppModel(repository: RunnerRepository(runners: []))
        let viewSize = CGSize(width: 240, height: 400)
        let baseTime = Date(timeIntervalSinceReferenceDate: 500)
        let allResults = [
            OCRBibResult(bibNumber: "101", confidence: 0.99, boundingBox: CGRect(x: 0.05, y: 0.2, width: 0.18, height: 0.1)),
            OCRBibResult(bibNumber: "102", confidence: 0.96, boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.18, height: 0.1)),
            OCRBibResult(bibNumber: "103", confidence: 0.93, boundingBox: CGRect(x: 0.15, y: 0.2, width: 0.18, height: 0.1)),
            OCRBibResult(bibNumber: "104", confidence: 0.91, boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.18, height: 0.1)),
            OCRBibResult(bibNumber: "105", confidence: 0.89, boundingBox: CGRect(x: 0.25, y: 0.2, width: 0.18, height: 0.1)),
            OCRBibResult(bibNumber: "200", confidence: 0.2, boundingBox: CGRect(x: 0.3, y: 0.2, width: 0.18, height: 0.1))
        ]

        for offset in stride(from: 0.0, through: 0.4, by: 0.2) {
            appModel.ingestOCRResults(
                allResults,
                viewSize: viewSize,
                now: baseTime.addingTimeInterval(offset)
            )
        }

        #expect(Set(appModel.trackedOverlays.keys) == Set(["101", "102", "103", "104"]))
        #expect(appModel.visibleTracks.count == 4)
        #expect(appModel.trackedOverlays["200"] == nil)
    }

}
