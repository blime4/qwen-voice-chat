import Foundation

// Simple test functions without XCTest
func runTests() {
    print("Running AudiobookApp tests...")
    
    testServiceNotLoadedByDefault()
    testAudioPlayerInitialState()
    
    print("All tests passed!")
}

func testServiceNotLoadedByDefault() {
    let service = ChatLLMService()
    assert(!service.isLoaded, "Service should not be loaded by default")
    print("✓ testServiceNotLoadedByDefault")
}

func testAudioPlayerInitialState() {
    let player = AudioPlayerService()
    assert(!player.isPlaying, "Player should not be playing initially")
    assert(player.currentProgress == 0.0, "Progress should be 0 initially")
    print("✓ testAudioPlayerInitialState")
}
