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
