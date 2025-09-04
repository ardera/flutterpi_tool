## 0.8.3 - 2025-09-04
- fix device diagnostics connecting to invalid device on `flutterpi_tool devices add`
- fix target device specification using `flutterpi_tool run -d`

## 0.8.2 - 2025-09-01
- fix artifacts resolving
- add test for artifacts resolving

## 0.8.1 - 2025-08-29
- add `--fs-layout=<flutter-pi/meta-flutter>` argument to
  `flutterpi_tool devices add` and `flutterpi_tool build`
- internal refactors, tests & improvements

## 0.8.0 - 2025-06-13
- add `--flutterpi-binary` argument to bundle a custom flutter-pi binary
  with the app
- flutter 3.32 compatibility
- internal artifact resolving refactors

## 0.7.3 - 2025-04-29
- add `flutterpi_tool test` subcommand
- supports running integration tests on registered devices, e.g.
  - `flutterpi_tool test integration_test -d pi`
- add `--dummy-display` and `--dummy-display-size` args for `flutterpi_tool devices add`
  - allows simulating a display, useful if no real display is attached

## 0.7.2 - 2025-04-29
- add `flutterpi_tool test` subcommand
- supports running integration tests on registered devices, e.g.
  - `flutterpi_tool test integration_test -d pi`
- add `--dummy-display` and `--dummy-display-size` args for `flutterpi_tool devices add`
  - allows simulating a display, useful if no real display is attached

## 0.7.1 - 2025-03-21
- fix missing executable permissions when running from windows
- fix app not terminating when running from windows

## 0.7.0 - 2025-03-20
- flutter 3.29 compatibility

## [0.6.0] - 2024-01-13
- fix "artifact may not be available in some environments" warnings
- 3.27 compatibility

## [0.5.4] - 2024-08-13
- fix `flutterpi_tool run -d` command for flutter 3.24

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
