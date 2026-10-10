# Family Controls distribution entitlement checklist

Development builds on your own device work with the development entitlement. Shipping (TestFlight external / App Store) needs Apple approval.

- [ ] Paid Apple Developer Program membership active
- [ ] App ID for the app **and each extension** (monitor, shield) created
- [ ] Request Family Controls (Distribution) for each App ID: https://developer.apple.com/contact/request/family-controls-distribution
- [ ] Prepared justification: purpose (reduce distracted driving), what is shielded, user-initiated selection, no message content collected
- [ ] Privacy policy URL live; matches App Privacy answers
- [ ] Screenshots/demo video of onboarding explaining Screen Time permission
- [ ] App Group enabled on app + extensions
- [ ] After approval: regenerate provisioning profiles, set entitlement in `project.yml`
- [ ] Test on TestFlight before submission
