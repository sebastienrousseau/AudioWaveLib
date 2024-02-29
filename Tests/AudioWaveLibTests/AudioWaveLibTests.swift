@testable import AudioWaveLib
import AVFoundation
import XCTest

class AudioWaveLibProviderTests: XCTestCase {
    var provider: AudioWaveLibProvider!

    override func setUp() {
        super.setUp()
        let audioFileURL = URL(fileURLWithPath: "./file.mp3")
        do {
            provider = try AudioWaveLibProvider(url: audioFileURL)
            provider.createSampleData() // Ensure sample data is created
        } catch {
            XCTFail("Failed to initialize AudioWaveLibProvider: \(error.localizedDescription)")
        }
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    func testInitializationWithValidURL() {
        XCTAssertNotNil(provider)
    }

    func testInitializationWithInvalidURL() {
        XCTAssertThrowsError(try AudioWaveLibProvider(url: URL(string: "invalidURL")!)) { error in
            XCTAssertTrue(error is AudioWaveLibProviderError)
        }
    }
}

class DemoDelegateTests: XCTestCase {
    var delegate: DemoDelegate!

    override func setUp() {
        super.setUp()
        delegate = DemoDelegate()
    }

    override func tearDown() {
        delegate = nil
        super.tearDown()
    }

    func testSampleProcessed() {
        guard let provider = try? AudioWaveLibProvider(url: URL(fileURLWithPath: "../../file.mp3")) else { return }
        delegate.sampleProcessed(provider: provider)
    }

    func testStatusUpdated() {
        let error = AudioWaveLibProviderError.invalidURL
        guard let provider = try? AudioWaveLibProvider(url: URL(fileURLWithPath: "../../file.mp3")) else { return }
        delegate.statusUpdated(provider: provider, withError: error)
    }
}
