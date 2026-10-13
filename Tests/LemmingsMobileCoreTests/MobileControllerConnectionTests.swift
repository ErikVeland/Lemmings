import Testing
@testable import LemmingsMobileCore

struct MobileControllerConnectionTests {
    @Test func disconnectDuringPlayPausesOnce() {
        var connection = MobileControllerConnection()

        #expect(!connection.update(isConnected: true, isMenu: false))
        #expect(connection.update(isConnected: false, isMenu: false))
        #expect(!connection.update(isConnected: false, isMenu: false))
    }

    @Test func disconnectOnMenuDoesNotRequestGameplayPause() {
        var connection = MobileControllerConnection()

        #expect(!connection.update(isConnected: true, isMenu: true))
        #expect(!connection.update(isConnected: false, isMenu: true))
    }

    @Test func lifecycleResetDoesNotRequestDisconnectPause() {
        var connection = MobileControllerConnection()

        #expect(!connection.update(isConnected: true, isMenu: false))
        connection.reset()
        #expect(!connection.update(isConnected: false, isMenu: false))
    }
}
