# flutterpi_tool
A tool to make developing &amp; distributing flutter apps for https://github.com/ardera/flutter-pi easier.

## 📰 News
- flutterpi_tool now supports running apps on devices directly.
- Windows and Linux armv7/arm64 are now supported for running flutterpi_tool.

## Setup
Setting up is as simple as:
```shell
flutter pub global activate flutterpi_tool
```

`flutterpi_tool` is pretty deeply integrated with the official flutter tool, so it's very well possible you encounter errors during this step when using incompatible versions.

If that happens, and `flutter pub global activate` exits with an error, make sure you're on the latest stable flutter SDK. If you're on an older flutter SDK, you might want to add an explicit dependency constraint to use an older version of flutterpi_tool. E.g. for flutter 3.19 you would use flutterpi_tool 0.3.x:

```shell
flutter pub global activate flutterpi_tool ^0.3.0
```

If you are already using the latest stable flutter SDK, and the command still doesn't work, please open an issue!

## Usage
```console
$ flutterpi_tool --help
A tool to make development & distribution of flutter-pi apps easier.

Usage: flutterpi_tool <command> [arguments]

Global options:
-h, --help         Print this usage information.
-d, --device-id    Target device id or name (prefixes allowed).

Other options
    --verbose      Enable verbose logging.

Available commands:

Flutter-Pi Tool
  precache   Populate the flutterpi_tool's cache of binary artifacts.

Project
  build      Builds a flutter-pi asset bundle.
  run        Run your Flutter app on an attached device.

Tools & Devices
  devices    List & manage flutterpi_tool devices.

Run "flutterpi_tool help <command>" for more information about a command.
```

## Examples
### 1. Adding a device
```console
$ flutterpi_tool devices add pi@pi5
Device "pi5" has been added successfully.
```

### 2. Adding a device with an explicit display size of 285x190mm, and a custom device name
```console
$ flutterpi_tool devices add pi@pi5 --display-size=285x190 --id=my-pi
Device "my-pi" has been added successfully.
```

### 3. Listing devices
```console
$ flutterpi_tool devices
Found 1 wirelessly connected device:
  pi5 (mobile) • pi5 • linux-arm64 • Linux

If you expected another device to be detected, try increasing the time to wait
for connected devices by using the "flutterpi_tool devices list" command with
the "--device-timeout" flag.
...
```

### 4. Creating and running an app on a remote device
```console
$ flutter create hello_world && cd hello_world

$ flutterpi_tool run -d pi5
Launching lib/main.dart on pi5 in debug mode...
Building Flutter-Pi bundle...
Installing app on device...
...
```

### 5. Running the same app in profile mode
```
$ flutterpi_tool run -d pi5 --profile
```
