import 'dart:io';
import 'package:args/command_runner.dart';

class InitCommand extends Command<int> {
  @override
  final String name = 'init';

  @override
  final String description = 'Initialize Guix reproducible build configuration.';

  InitCommand() {
    argParser.addFlag('force', abbr: 'f', help: 'Overwrite existing files');
  }

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;

    // Check if guix-flutter-scripts is already present (subtree installed).
    final guixDir = Directory('guix');
    if (guixDir.existsSync() && Directory('guix/scripts').existsSync()) {
      // Scripts are present: delegate to bootstrap.sh if it exists.
      final bootstrapScript = File('guix/bootstrap.sh');
      if (bootstrapScript.existsSync()) {
        print('Found guix-flutter-scripts. Running bootstrap...');
        final process = await Process.start(
          'bash', [bootstrapScript.path],
          mode: ProcessStartMode.inheritStdio,
        );
        return process.exitCode;
      }
    }

    // No subtree installed: create minimal config files.
    print('Setting up minimal Guix configuration...');
    print('');
    print('For the full scripts package, add via git subtree:');
    print('  git subtree add --prefix=guix <repo-url> main --squash');
    print('  guix/bootstrap.sh');
    print('');

    var wrote = 0;

    // Create guix-flutter.conf
    wrote += _writeIfMissing(
      'guix-flutter.conf',
      'GUIX_FLUTTER_DIR="guix"\n',
      force,
    );

    // Create flutter_version.env
    wrote += _writeIfMissing(
      'flutter_version.env',
      '# Pinned Flutter SDK version for reproducible builds.\n'
      'FLUTTER_VERSION="3.24.5"\n'
      'FLUTTER_CHANNEL="stable"\n'
      'FLUTTER_SHA256_X64=""\n'
      'FLUTTER_SHA256_ARM64=""\n',
      force,
    );

    // Create android_sdk_version.env
    wrote += _writeIfMissing(
      'android_sdk_version.env',
      '# Pinned Android SDK component versions.\n'
      'ANDROID_CMDLINE_TOOLS_BUILD="14742923"\n'
      'ANDROID_CMDLINE_TOOLS_SHA256=""\n'
      'ANDROID_PLATFORM_VERSION="android-34"\n'
      'ANDROID_BUILD_TOOLS_VERSION="34.0.0"\n'
      'ANDROID_NDK_VERSION="23.1.7779620"\n',
      force,
    );

    if (wrote > 0) {
      print('Created $wrote config file(s).');
    } else {
      print('All config files already exist.');
    }
    print('');
    print('Next: add guix-flutter-scripts via git subtree, then run:');
    print('  guix_dart setup');
    return 0;
  }

  int _writeIfMissing(String path, String content, bool force) {
    final file = File(path);
    if (file.existsSync() && !force) {
      print('  $path already exists (use --force to overwrite)');
      return 0;
    }
    file.writeAsStringSync(content);
    print('  Created $path');
    return 1;
  }
}
