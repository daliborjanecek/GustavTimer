# Challenge Pack Asset Bundle

This directory holds the 12 video files that make up the Gustav Timer
Challenge Pack delivered via Apple Background Assets (iOS 26+).

## Layout

```
ChallengePackAssets/
├── manifest.json
└── videos/
    ├── 01_duckwalk.mp4
    ├── 02_wallsit.mp4
    ├── 03_mountainclimbers.mp4
    ├── 04_legraises.mp4
    ├── 05_plank.mp4
    ├── 06_jumplunges.mp4
    ├── 07_burpees.mp4
    ├── 08_pushups.mp4
    ├── 09_squats.mp4
    ├── 10_lunges.mp4
    ├── 11_situps.mp4
    └── 12_high_knees.mp4
```

The numeric prefix preserves the playback order and matches the order shown
in `ChallengeVideoListView`.

## Identifiers

| Field            | Value                                               |
|------------------|-----------------------------------------------------|
| Pack identifier  | `cz.daliborjanecek.GustavTimer.ChallengePack`       |
| App group        | `group.cz.daliborjanecek.GustavTimer`               |
| Essential        | `false` (on-demand only)                            |

## Packaging & Upload

Apple ships a packaging tool with Xcode 26. To build the asset pack:

```bash
xcrun ba-package \
    --input ChallengePackAssets \
    --output ChallengePack.aar \
    --identifier cz.daliborjanecek.GustavTimer.ChallengePack
```

Verify the archive with:

```bash
xcrun ba-package --validate ChallengePack.aar
```

Upload the `.aar` to App Store Connect:

1. Open the app record → **Background Assets** tab.
2. Drag in `ChallengePack.aar` (or use Transporter / `xcrun altool`).
3. Mark the pack as **On-Demand** so it is not pulled at install time.
4. Submit for review alongside the next app version.

For development, a small placeholder pack can be staged manually by copying
this directory into the app group container of the simulator:

```bash
APP_GROUP_DIR="$(xcrun simctl get_app_container booted cz.daliborjanecek.GustavTimer groups)/group.cz.daliborjanecek.GustavTimer"
cp -R ChallengePackAssets/videos "$APP_GROUP_DIR/ChallengePack"
```

`ChallengePackManager.refreshStateFromDisk()` will then report the pack as
downloaded on next app launch.
