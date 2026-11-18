import Foundation

@main
enum LaunchURLTests {
    static func main() {
        for scheme in ["ultimatelemmings", "ultimatelemmix"] {
            let info: [String: Any] = ["CFBundleURLTypes": [["CFBundleURLSchemes": [scheme]]]]
            precondition(AppleMobileLaunchURL.opensDeskClock(URL(string: "\(scheme)://desk-clock")!, info: info))
            precondition(!AppleMobileLaunchURL.opensDeskClock(URL(string: "other://desk-clock")!, info: info))
            precondition(!AppleMobileLaunchURL.opensDeskClock(URL(string: "\(scheme)://home")!, info: info))
        }
        let multiple: [String: Any] = ["CFBundleURLTypes": [
            ["CFBundleURLSchemes": ["unrelated"]],
            ["CFBundleURLSchemes": ["UPPERCASE", "second"]]
        ]]
        precondition(AppleMobileLaunchURL.opensDeskClock(URL(string: "uppercase://desk-clock")!, info: multiple))
        precondition(AppleMobileLaunchURL.opensDeskClock(URL(string: "second://desk-clock")!, info: multiple))
        precondition(!AppleMobileLaunchURL.opensDeskClock(URL(string: "ultimatelemmings://desk-clock")!, info: [:]))
        precondition(!AppleMobileLaunchURL.opensDeskClock(URL(string: "ultimatelemmix://desk-clock")!,
            info: ["CFBundleURLTypes": "invalid"]))
        print("PASS mobile launch URL metadata contracts")
    }
}
