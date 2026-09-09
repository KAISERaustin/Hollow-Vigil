# Campaign verification

Run `./launch.ps1 -Tests` for authored Campaign simulation, content configuration, build export, checkpoints and placement. Run `-UnifiedTests` for Campaign navigation, persistence and backup-client regressions. Run `-MobileTests` for portrait layout and touch interaction, or `-Check` for the combined supported suite.

All runners use isolated data under `.runtime/tests`. The launcher imports resources, performs script checks, checks process exit codes, and scans logs for engine errors. Portrait coverage uses 360×640, 390×844 and 540×960. Desktop simulated touch does not establish physical iOS/Android acceptance.

`campaign_only_runner.gd` checks application startup, three-slot creation/continue, map/battle transitions, checkpoint persistence, sound preferences and Campaign-only backup/build boundaries.
