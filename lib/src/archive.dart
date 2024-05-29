// The archive package that the flutter SDK uses (3.3.2 as of 29-05-2024)
// has a bug where it can't properly extract xz archives (I suspect when they
// where created with multithreaded compression)
// So we frankenstein together a newer XZDecoder from archive 3.6.0 with the
// archive 3.3.2 that flutter uses.
export 'package:archive/archive_io.dart' hide XZDecoder;
export 'archive/xz_decoder.dart';
