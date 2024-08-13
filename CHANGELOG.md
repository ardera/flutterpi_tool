## [0.5.3] - 2024-08-13
- Fix artifact finding when github API results are paginated

## [0.5.2] - 2024-08-09
- Flutter 3.24 compatibility
- Print a nicer error message if engine artifacts are not yet available

## [0.5.1] - 2024-08-08
- Expand remote user permissions check to `render` group, since that's necessary as well to use the hardware GPU.
- Added a workaround for an issue where the executable permission of certain files would be lost when copying them to the output directory, causing errors when trying to run the app on the target.
- Reduced the amount of GitHub API traffic generated when checking for updates to flutter-pi, to avoid rate limiting.
- Changed the severity of the `failed to check for flutter-pi updates` message to a warning to avoid confusion.

## [0.5.0] - 2024-06-26

- add `run` and `devices` subcommands
- add persistent flutterpi_tool config for devices
- update Readme
- constrain to flutter 3.22.0

## [0.4.1] - 2024-06-15

### 📚 Documentation

- Mention version conflicts in README

## 0.4.0

- fix for flutter 3.22

## 0.3.0

- fix for flutter 3.19

## 0.2.1

- fix gen_snapshot selection

## 0.2.0

- add macos host support
- add `--dart-define`, `--dart-define-from-file`, `--target` flags
- add `--debug-symbols` flag
- add support for v2 artifact layout

## 0.1.2

- update `flutterpi_tool --help` in readme

## 0.1.1

- update `flutterpi_tool build help` in readme

## 0.1.0

- add x64 support with `--arch=x64` (and `--cpu=generic`)
- fix stale `app.so` when switching architectures (or cpus)
- fix `--tree-shake-icons` defaults
- fix inconsistent cached artifact versions 

## 0.0.5

- add `precache` command

## 0.0.4

- update readme for new build option

## 0.0.3

- remove some logging
- add `--[no-]-tree-shake-icons` flag
  - sometimes tree shaking is impossible, in which case
    it's necessary to specify `--no-tree-shake-icons`, otherwise
    the tool will error

## 0.0.2

- rename global executable `flutterpi-tool ==> flutterpi_tool`

## 0.0.1

- Initial version.
