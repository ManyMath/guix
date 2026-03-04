import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:guix/src/guix/guix_runner.dart';
import 'package:guix/src/templates/linux_manifest.dart';
import 'package:guix/src/templates/android_manifest.dart';
import 'package:guix/src/templates/config_template.dart';

class InitCommand extends Command<int> {
  @override
  final String name = 'init';

  @override
  final String description = 'Initialize Guix reproducible build configuration.';

  InitCommand() {
    argParser
      ..addFlag('force', abbr: 'f', help: 'Overwrite existing files')
      ..addFlag('from-existing', help: 'Generate config from existing .env files');
  }

  @override
  String get invocation => '${runner!.executableName} init [linux] [android]';

  @override
  Future<int> run() async {
    final force = argResults!['force'] as bool;
    final fromExisting = argResults!['from-existing'] as bool;
    final verbose = globalResults!['verbose'] as bool;
    final platforms = argResults!.rest.isEmpty
        ? <String>['linux']  // default to linux
        : argResults!.rest;

    final projectName = p.basename(Directory.current.path);

    if (fromExisting) {
      return _initFromExisting(projectName, force, verbose);
    }

    var wrote = 0;

    // Create guix.yaml
    final configFile = File('guix.yaml');
    if (configFile.existsSync() && !force) {
      print('guix.yaml already exists (use --force to overwrite)');
    } else {
      final content = generateConfig(
        projectName: projectName,
        platforms: platforms,
      );
      configFile.writeAsStringSync(content);
      print('Created guix.yaml');
      wrote++;
    }

    // Create guix/ directory
    final guixDir = Directory('guix');
    if (!guixDir.existsSync()) {
      guixDir.createSync();
    }

    // Write manifest templates
    final manifestMap = {
      'linux': linuxManifestTemplate,
      'android': androidManifestTemplate,
    };

    for (final platform in platforms) {
      final template = manifestMap[platform];
      if (template == null) {
        stderr.writeln('No built-in template for platform: $platform');
        stderr.writeln('Create guix/$platform.scm manually.');
        continue;
      }

      final manifestFile = File('guix/$platform.scm');
      if (manifestFile.existsSync() && !force) {
        print('guix/$platform.scm already exists (use --force to overwrite)');
      } else {
        manifestFile.writeAsStringSync(template);
        print('Created guix/$platform.scm');
        wrote++;
      }
    }

    // Pin channels
    final channelsFile = File('guix/channels.scm');
    if (channelsFile.existsSync() && !force) {
      print('guix/channels.scm already exists (use --force to overwrite)');
    } else {
      final guix = GuixRunner(verbose: verbose);
      if (await guix.isInstalled()) {
        print('Pinning Guix channels...');
        final result = await guix.pinChannels('guix/channels.scm');
        if (result.exitCode == 0) {
          print('Created guix/channels.scm');
          wrote++;
        } else {
          stderr.writeln('Failed to pin channels: ${result.stderr}');
          stderr.writeln('You can pin manually later with: guix_dart pin');
        }
      } else {
        print('Guix not found: skipping channel pinning.');
        print('Install Guix, then run: guix_dart pin');
      }
    }

    print('');
    if (wrote > 0) {
      print('Initialized $wrote file(s). Next steps:');
      print('  guix_dart setup          # fetch Flutter SDK');
      print('  guix_dart shell linux    # enter dev shell');
    } else {
      print('Nothing to do (all files already exist).');
    }
    return 0;
  }

  /// Initialize from existing .env files (migration path).
  Future<int> _initFromExisting(String projectName, bool force, bool verbose) async {
    var flutterVersion = '3.24.5';
    var flutterChannel = 'stable';
    var checksumX64 = '';
    var checksumArm64 = '';
    final platforms = <String>[];

    // Read flutter_version.env if it exists
    final flutterEnv = File('flutter_version.env');
    if (flutterEnv.existsSync()) {
      final lines = flutterEnv.readAsLinesSync();
      for (final line in lines) {
        _parseEnvLine(line, 'FLUTTER_VERSION', (v) => flutterVersion = v);
        _parseEnvLine(line, 'FLUTTER_CHANNEL', (v) => flutterChannel = v);
        _parseEnvLine(line, 'FLUTTER_SHA256_X64', (v) => checksumX64 = v);
        _parseEnvLine(line, 'FLUTTER_SHA256_ARM64', (v) => checksumArm64 = v);
      }
      print('Found flutter_version.env (version: $flutterVersion)');
    }

    // Android SDK fields
    var cmdlineToolsBuild = '14742923';
    var cmdlineToolsSha256 = '';
    var platformVersion = 'android-34';
    var buildToolsVersion = '34.0.0';
    var ndkVersion = '23.1.7779620';

    final androidEnv = File('android_sdk_version.env');
    if (androidEnv.existsSync()) {
      final lines = androidEnv.readAsLinesSync();
      for (final line in lines) {
        _parseEnvLine(line, 'ANDROID_CMDLINE_TOOLS_BUILD', (v) => cmdlineToolsBuild = v);
        _parseEnvLine(line, 'ANDROID_CMDLINE_TOOLS_SHA256', (v) => cmdlineToolsSha256 = v);
        _parseEnvLine(line, 'ANDROID_PLATFORM_VERSION', (v) => platformVersion = v);
        _parseEnvLine(line, 'ANDROID_BUILD_TOOLS_VERSION', (v) => buildToolsVersion = v);
        _parseEnvLine(line, 'ANDROID_NDK_VERSION', (v) => ndkVersion = v);
      }
      print('Found android_sdk_version.env');
    }

    // Detect platforms from existing manifests
    if (File('guix/linux.scm').existsSync()) {
      platforms.add('linux');
      print('Found guix/linux.scm');
    }
    if (File('guix/android.scm').existsSync()) {
      platforms.add('android');
      print('Found guix/android.scm');
    }

    if (platforms.isEmpty) {
      platforms.add('linux'); // fallback
    }

    // Write config
    final configFile = File('guix.yaml');
    if (configFile.existsSync() && !force) {
      print('guix.yaml already exists (use --force to overwrite)');
      return 0;
    }

    final content = generateConfig(
      projectName: projectName,
      platforms: platforms,
      flutterVersion: flutterVersion,
      flutterChannel: flutterChannel,
      checksumX64: checksumX64,
      checksumArm64: checksumArm64,
      cmdlineToolsBuild: cmdlineToolsBuild,
      cmdlineToolsSha256: cmdlineToolsSha256,
      platformVersion: platformVersion,
      buildToolsVersion: buildToolsVersion,
      ndkVersion: ndkVersion,
    );
    configFile.writeAsStringSync(content);
    print('Created guix.yaml from existing configuration.');
    print('');
    print('Your existing scripts and .env files are untouched.');
    print('Both workflows now work in parallel.');
    return 0;
  }

  /// Parse a shell-style `KEY="value"` or `KEY=value` line and call [setter] if the key matches.
  void _parseEnvLine(String line, String key, void Function(String) setter) {
    final match = RegExp('^$key="?([^"]*)"?').firstMatch(line);
    if (match != null) setter(match.group(1)!);
  }
}
