---
name: cyl-simulator-run
description: Rules for running an iOS simulator in this repository. Read before booting a simulator, installing or launching an app, or taking test screenshots. After the screenshots, terminate the app and shut down the simulator right away.
---

# Simulator run rules

The same rule is in `instructions.md` ("Simulator rules"). When they disagree, `instructions.md` wins; fix this file.

## Rule (verbatim intent)

After a simulator run and its test screenshots, immediately kill the app and the simulator process. Start them again when they are needed. Never leave the app running or the simulator booted after the task is done.

## Checklist

1. Before booting: read this file or the "Simulator rules" section of `instructions.md`.
2. Use a simulator of your own, addressed by UDID.
3. Run the test and take the screenshots in one pass (static code first, then one test batch).
4. Right after the last screenshot: `xcrun simctl terminate <UDID> <bundle id>`, then `xcrun simctl shutdown <UDID>`.
5. Never `xcrun simctl shutdown all`: it also stops the simulators of other sessions on this Mac.
6. Check: `xcrun simctl list devices | grep Booted` shows none of yours. A later run boots it again.
7. A simulator you created only for one task may also be deleted with `xcrun simctl delete <UDID>`.
