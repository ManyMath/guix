import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:guix/src/config/guix_config.dart';
import 'package:guix/src/guix/guix_runner.dart';

class ShellCommand extends Command<int> {
  @override
  final String name = 'shell';

  @override
  final String description = 'Enter an interactive Guix development shell.';

  ShellCommand() {
    argParser
      ..addFlag('pinned', abbr: 'p', help: 'Use pinned Guix channels (slower, reproducible)');
  }

  @override
  String get invocation => '${runner!.executableName} shell <platform>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      stderr.writeln('Error: platform argument required.');
      printUsage();
      return 1;
    }

    final platformName = argResults!.rest.first;
    final pinned = argResults!['pinned'] as bool;
    final verbose = globalResults!['verbose'] as bool;
    final config = GuixConfig.load();

    final platform = config.platforms[platformName];
    if (platform == null) {
      stderr.writeln('Unknown platform: $platformName');
      stderr.writeln('Available: ${config.platformNames.join(', ')}');
      return 1;
    }

    // Validate SDK exists
    final sdkDir = Directory('.flutter-sdk/flutter');
    if (!sdkDir.existsSync()) {
      stderr.writeln('Flutter SDK not found. Run: guix_dart setup');
      return 1;
    }

    // Validate manifest exists
    if (!File(platform.manifest).existsSync()) {
      stderr.writeln('Manifest not found: ${platform.manifest}');
      stderr.writeln('Run: guix_dart init $platformName');
      return 1;
    }

    final guixRunner = GuixRunner(verbose: verbose);
    final channelsFile = pinned ? config.channelsPath : null;
    if (pinned && !File(config.channelsPath).existsSync()) {
      stderr.writeln('Channels file not found: ${config.channelsPath}');
      stderr.writeln('Run: guix_dart pin');
      return 1;
    }

    final sdkPath = sdkDir.absolute.path;
    print('Entering $platformName shell${pinned ? ' (pinned)' : ''}...');

    return guixRunner.enterShell(
      manifest: platform.manifest,
      channelsFile: channelsFile,
      env: platform.env,
      preserveVars: platform.preserve,
      flutterSdkPath: sdkPath,
    );
  }
}
