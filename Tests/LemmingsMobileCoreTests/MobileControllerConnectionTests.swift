import Testing
@testable import LemmingsMobileCore

struct MobileControllerConnectionTests {
    @Test func disconnectDuringPlayPausesOnce() {
        var connection = MobileControllerConnection()

        let connected = connection.update(isConnected: true, isMenu: false)
        let disconnected = connection.update(isConnected: false, isMenu: false)
        let stillDisconnected = connection.update(isConnected: false, isMenu: false)

        #expect(!connected)
        #expect(disconnected)
        #expect(!stillDisconnected)
    }

    @Test func disconnectOnMenuDoesNotRequestGameplayPause() {
        var connection = MobileControllerConnection()

        let connected = connection.update(isConnected: true, isMenu: true)
        let disconnected = connection.update(isConnected: false, isMenu: true)

        #expect(!connected)
        #expect(!disconnected)
    }

    @Test func lifecycleResetDoesNotRequestDisconnectPause() {
        var connection = MobileControllerConnection()

        let connected = connection.update(isConnected: true, isMenu: false)
        #expect(!connected)
        connection.reset()
        let disconnected = connection.update(isConnected: false, isMenu: false)
        #expect(!disconnected)
    }
}
