import SwiftUI

/// Setup tips and honest limits, moved out of Settings so that screen stays short.
struct HowItWorksView: View {
    var body: some View {
        Form {
            Section {
                Text("**Let Messages be blocked.** Open iOS Settings, then Screen Time, then Always Allowed, and remove Messages. Until you do, iOS keeps Messages open no matter what DriveLock does.")
                Text("**Set Location to Always.** That's how DriveLock notices a drive when the app is closed.")
                Text("**Pick Maps and music in Strict mode.** Strict mode blocks everything except the apps you allow.")
                Text("**Passenger?** Tap \"I'm a passenger\" on the main screen. It turns shields off for that drive and ends your streak, because DriveLock can't tell who is driving.")
            } header: { Text("How to use it") }

            Section {
                Text("DriveLock can't lock your phone. It shields apps, so opening one shows a block screen. Phone calls and some system apps can't be shielded.")
                Text("Shields come on about a minute after you start driving and turn off about a minute after you stop moving. A stop longer than a minute, like a long red light, also ends the drive.")
                Text("Pickups are counted from phone motion and are approximate.")
                Text("Message contents are never read. Trips stay on your phone.")
            } header: { Text("What to expect") }
        }
        .navigationTitle("How DriveLock works")
        .navigationBarTitleDisplayMode(.inline)
    }
}
