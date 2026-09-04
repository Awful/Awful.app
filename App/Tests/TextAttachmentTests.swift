//  TextAttachmentTests.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@testable import Awful
import UIKit
import XCTest

final class TextAttachmentTests: XCTestCase {

    private func makeImage(width: CGFloat, height: CGFloat, opaque: Bool = true) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    private func roundTrip(_ attachment: TextAttachment) throws -> TextAttachment {
        let attributed = NSAttributedString(attachment: attachment)
        let data = try NSKeyedArchiver.archivedData(withRootObject: attributed, requiringSecureCoding: false)
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        let decoded = try XCTUnwrap(unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString)
        return try XCTUnwrap(decoded.attribute(.attachment, at: 0, effectiveRange: nil) as? TextAttachment)
    }

    func testSmallImageThumbnailIsTheImageItselfAndCached() {
        let image = makeImage(width: 100, height: 100)
        let attachment = TextAttachment(image: image, photoAssetIdentifier: nil)

        XCTAssertTrue(attachment.thumbnailImage === image)
        XCTAssertTrue(attachment.thumbnailImage === attachment.thumbnailImage)
    }

    func testLargeImageThumbnailIsScaledDownAndCached() throws {
        let attachment = TextAttachment(image: makeImage(width: 4000, height: 3000), photoAssetIdentifier: nil)

        let thumbnail = try XCTUnwrap(attachment.thumbnailImage)
        XCTAssertLessThanOrEqual(thumbnail.size.width, 800)
        XCTAssertLessThanOrEqual(thumbnail.size.height, 600)
        XCTAssertTrue(attachment.thumbnailImage === thumbnail)
    }

    func testSettingImageInvalidatesThumbnail() throws {
        let attachment = TextAttachment(image: makeImage(width: 4000, height: 3000), photoAssetIdentifier: nil)
        let first = try XCTUnwrap(attachment.thumbnailImage)

        attachment.image = makeImage(width: 50, height: 50)

        XCTAssertFalse(attachment.thumbnailImage === first)
        XCTAssertEqual(attachment.thumbnailImage?.size, CGSize(width: 50, height: 50))
    }

    func testArchiveWithoutAssetPreservesFullSizeImage() throws {
        let attachment = TextAttachment(image: makeImage(width: 1600, height: 1200), photoAssetIdentifier: nil)
        let prepared = expectation(description: "prepared")
        attachment.prepareArchivableImageData { prepared.fulfill() }
        wait(for: [prepared], timeout: 5)
        XCTAssertFalse(attachment.isPreparingArchivableImageData)

        let decoded = try roundTrip(attachment)

        XCTAssertNil(decoded.photoAssetIdentifier)
        XCTAssertEqual(decoded.image?.size, CGSize(width: 1600, height: 1200))
    }

    func testArchiveBeforeBytesAreReadyStillCarriesAnImage() throws {
        let attachment = TextAttachment(image: makeImage(width: 4000, height: 3000), photoAssetIdentifier: nil)

        let decoded = try roundTrip(attachment)

        let image = try XCTUnwrap(decoded.image)
        XCTAssertLessThanOrEqual(image.size.width, 800)
        XCTAssertLessThanOrEqual(image.size.height, 600)
    }

    func testAssetBackedArchiveStaysSmallAndKeepsIdentifier() throws {
        let attachment = TextAttachment(image: makeImage(width: 4000, height: 3000), photoAssetIdentifier: "not-a-real-asset")
        let prepared = expectation(description: "prepared")
        attachment.prepareArchivableImageData { prepared.fulfill() }
        wait(for: [prepared], timeout: 5)

        let data = try NSKeyedArchiver.archivedData(withRootObject: NSAttributedString(attachment: attachment), requiringSecureCoding: false)
        XCTAssertLessThan(data.count, 1_000_000)

        let decoded = try roundTrip(attachment)
        XCTAssertEqual(decoded.photoAssetIdentifier, "not-a-real-asset")
        // The asset can't be found, so the stored thumbnail keeps the attachment visible.
        XCTAssertNotNil(decoded.image)
    }

    func testPrepareIsIdempotentWhileInFlight() {
        let attachment = TextAttachment(image: makeImage(width: 300, height: 300), photoAssetIdentifier: nil)
        let first = expectation(description: "first")
        attachment.prepareArchivableImageData { first.fulfill() }
        XCTAssertTrue(attachment.isPreparingArchivableImageData)
        // Second call while the first is in flight completes immediately without starting another encode.
        let second = expectation(description: "second")
        attachment.prepareArchivableImageData { second.fulfill() }
        wait(for: [first, second], timeout: 5)
        XCTAssertFalse(attachment.isPreparingArchivableImageData)
    }

    func testLegacyArchiveDecodesThroughNSTextAttachment() throws {
        // Drafts saved by older builds archived via NSTextAttachment's own coding.
        let legacy = NSTextAttachment()
        legacy.image = makeImage(width: 120, height: 80)
        let data = try NSKeyedArchiver.archivedData(withRootObject: NSAttributedString(attachment: legacy), requiringSecureCoding: false)

        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        unarchiver.setClass(TextAttachment.self, forClassName: "NSTextAttachment")
        let decoded = try XCTUnwrap(unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString)
        let attachment = try XCTUnwrap(decoded.attribute(.attachment, at: 0, effectiveRange: nil) as? TextAttachment)

        XCTAssertNil(attachment.photoAssetIdentifier)
        XCTAssertNotNil(attachment.image)
    }

    func testHasTextAttachmentsPreparingForArchive() {
        let attachment = TextAttachment(image: makeImage(width: 300, height: 300), photoAssetIdentifier: nil)
        let text = NSMutableAttributedString(string: "before ")
        text.append(NSAttributedString(attachment: attachment))
        XCTAssertFalse(text.hasTextAttachmentsPreparingForArchive)

        let prepared = expectation(description: "prepared")
        attachment.prepareArchivableImageData { prepared.fulfill() }
        XCTAssertTrue(text.hasTextAttachmentsPreparingForArchive)
        wait(for: [prepared], timeout: 5)
        XCTAssertFalse(text.hasTextAttachmentsPreparingForArchive)
    }
}
