import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:guix/src/config/guix_config.dart';
import 'package:guix/src/guix/guix_runner.dart';

class BuildCommand extends Command<int> {
  @override
  final String name = 'build';

  @override
  final String description = 'Build inside a reproducible Guix environment.';

  BuildCommand() {
    argParser
      ..addFlag('pinned', abbr: 'p', defaultsTo: true,
          help: 'Use pinned Guix channels (default: true)')
      ..addOption('profile', abbr: 'P', help: 'Use a named build profile');
  }

  @override
  String get invocation => '${runner!.executableName} build <platform>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      stderr.writeln('Error: platform argument required.');
      printUsage();
      return 1;
    }

    final target = argResults!.rest.first;
    final pinned = argResults!['pinned'] as bool;
    final profileName = argResults!['profile'] as String?;
    final verbose = globalResults!['verbose'] as bool;
    final config = GuixConfig.load();

    // Resolve platform config (may come from a profile)
    final resolvedName = profileName ?? target;
    final platform = config.platformFor(resolvedName) ?? config.platforms[target];
    if (platform == null) {
      stderr.writeln('Unknown platform or profile: $resolvedName');
      stderr.writeln('Platforms: ${config.platformNames.join(', ')}');
      stderr.writeln('Profiles: ${config.profiles.keys.join(', ')}');
      return 1;
    }

    // Validate
    final sdkDir = Directory('.flutter-sdk/flutter');
    if (!sdkDir.existsSync()) {
      stderr.writeln('Flutter SDK not found. Run: guix_dart setup');
      return 1;
    }
    if (!File(platform.manifest).existsSync()) {
      stderr.writeln('Manifest not found: ${platform.manifest}');
      return 1;
    }

    final channelsFile = pinned ? config.channelsPath : null;
    if (pinned && !File(config.channelsPath).existsSync()) {
      stderr.writeln('Channels file not found: ${config.channelsPath}');
      stderr.writeln('Run: guix_dart pin');
      return 1;
    }

    final guix = GuixRunner(verbose: verbose);
    final sdkPath = sdkDir.absolute.path;

    print('Building ${platform.name}${pinned ? ' (pinned)' : ''}...');
    print('Command: ${platform.buildCommand}');

    final buildCmd = 'flutter pub get && ${platform.buildCommand}';
    final exitCode = await guix.runInShell(
      manifest: platform.manifest,
      channelsFile: channelsFile,
      env: platform.env,
      preserveVars: platform.preserve,
      flutterSdkPath: sdkPath,
      command: buildCmd,
    );

    if (exitCode == 0) {
      print('Build complete: ${platform.buildOutput}');
    } else {
      stderr.writeln('Build failed with exit code $exitCode');
    }
    return exitCode;
  }
}
