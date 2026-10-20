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
                Text("**Shield the apps that pull you in.** Messages, social apps (Instagram, TikTok, Snapchat, X, Facebook), browsers, YouTube, email and games.")
                Text("**Keep open what you need to drive.** Maps or Waze, your music or podcast app, and Phone.")
                Text("**Set it up before you pull away.** Enter your destination and start your playlist, podcast or audiobook while parked. A shielded app can't be opened once you're moving.")
                Text("**Put the phone out of reach.** A mount for navigation, or the back seat or glove box if you don't need it.")
                Text("**Use your car's controls.** Steering-wheel buttons or CarPlay skip songs without picking up the phone.")
                Text("**Optional: Driving Focus.** In iOS Settings, Focus, Driving, set it to turn on while driving. It silences notifications and can text back \"I'm driving.\"")
            } header: { Text("Best practices") }

            Section {
                Text("DriveLock can't lock your phone. It shields apps, so opening one shows a block screen. Phone calls and some system apps can't be shielded.")
                Text("Shields come on once iOS lets DriveLock notice the drive, usually within the first few minutes, and turn off about a minute after you stop moving. A stop longer than a minute, like a long red light, also ends the drive.")
                Text("Pickups are counted from phone motion and are approximate.")
                Text("Message contents are never read. Trips stay on your phone.")
            } header: { Text("What to expect") }
        }
        .navigationTitle("How DriveLock works")
        .navigationBarTitleDisplayMode(.inline)
    }
}
