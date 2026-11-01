//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

@testable import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import TestPublications
import Testing
import UIKit

@MainActor struct PDFNavigatorPreferencesTests {
    /// Submitting preferences rebuilds the PDF view at the current location.
    @Test func submittingPreferencesKeepsThePage() async throws {
        let navigator = try await makeNavigator(at: 5)

        navigator.submitPreferences(PDFPreferences(scroll: true))
        await navigator.resetTask?.value

        #expect(navigator.currentLocation?.locations.page == 5)
    }

    /// Preferences submitted while the PDF view is still being rebuilt for
    /// the previous ones (a user preferences screen saving to two stores, a
    /// menu and a preferences screen both submitting) keep the page too. The
    /// new PDF view has no document until it is loaded, so its current
    /// location is not the user's.
    @Test func preferencesSubmittedDuringARebuildKeepThePage() async throws {
        let navigator = try await makeNavigator(at: 5)

        let previousView = navigator.pdfView
        navigator.submitPreferences(PDFPreferences(scroll: true))
        let firstReset = navigator.resetTask
        // Let the rebuild start: it swaps in a new PDF view, then waits for
        // the document.
        while navigator.pdfView === previousView {
            await Task.yield()
        }
        try #require(navigator.pdfView?.document == nil)

        navigator.submitPreferences(PDFPreferences(scroll: true))
        let secondReset = navigator.resetTask
        await firstReset?.value
        await secondReset?.value

        #expect(navigator.currentLocation?.locations.page == 5)
    }

    private func makeNavigator(at page: Int) async throws -> PDFNavigatorViewController {
        let httpClient = DefaultHTTPClient()
        let assetRetriever = AssetRetriever(httpClient: httpClient)
        let opener = PublicationOpener(
            parser: DefaultPublicationParser(
                httpClient: httpClient,
                assetRetriever: assetRetriever,
                pdfFactory: DefaultPDFDocumentFactory()
            ),
            contentProtections: []
        )
        let url = try #require(FileURL(url: TestPublications.url(for: "daisy.pdf")))
        let asset = try await assetRetriever.retrieve(url: url).get()
        let publication = try await opener.open(asset: asset, allowUserInteraction: false, sender: nil).get()

        let navigator = try PDFNavigatorViewController(publication: publication, initialLocation: nil)
        navigator.view.frame = CGRect(x: 0, y: 0, width: 400, height: 600)
        try await waitUntilShowing(navigator)

        let link = try #require(publication.readingOrder.first)
        let locator = Locator(
            href: link.url(),
            mediaType: .pdf,
            locations: .init(fragments: ["page=\(page)"])
        )
        _ = await navigator.go(to: locator)
        try #require(navigator.currentLocation?.locations.page == page)

        return navigator
    }

    /// Waits for the PDF view to show its document.
    private func waitUntilShowing(_ navigator: PDFNavigatorViewController) async throws {
        for _ in 0 ..< 500 {
            if navigator.pdfView?.document != nil, navigator.currentLocation != nil {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        Issue.record("The PDF view did not show its document")
    }
}
