import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:guix/src/config/project_config.dart';

class SetupCommand extends Command<int> {
  @override
  final String name = 'setup';

  @override
  final String description = 'Fetch Flutter SDK and platform SDKs.';

  @override
  String get invocation => '${runner!.executableName} setup [platform...]';

  @override
  Future<int> run() async {
    final config = ProjectConfig.load();
    final targets = argResults!.rest;

    if (!config.hasScripts) {
      stderr.writeln('Scripts not found at ${config.guixDir}/scripts/');
      stderr.writeln('Add guix-flutter-scripts to your project first.');
      return 1;
    }

    // Always fetch Flutter SDK.
    print('Fetching Flutter SDK ${config.flutter.version}...');
    final fetchFlutter = config.scriptPath('fetch-flutter.sh');
    var exitCode = await _runScript(fetchFlutter);
    if (exitCode != 0) return exitCode;

    // Fetch platform-specific SDKs if requested.
    final platformTargets = targets.isEmpty
        ? config.platforms
        : targets;

    for (final platform in platformTargets) {
      final fetchScript = config.scriptPath('fetch-$platform-sdk.sh');
      if (File(fetchScript).existsSync()) {
        print('Fetching $platform SDK...');
        exitCode = await _runScript(fetchScript);
        if (exitCode != 0) return exitCode;
      }
    }

    print('Setup complete.');
    return 0;
  }

  Future<int> _runScript(String path) async {
    final process = await Process.start(
      'bash', [path],
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}
