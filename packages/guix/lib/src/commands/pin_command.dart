import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:guix/src/config/project_config.dart';

class PinCommand extends Command<int> {
  @override
  final String name = 'pin';

  @override
  final String description = 'Pin current Guix channels to channels.scm.';

  @override
  Future<int> run() async {
    final config = ProjectConfig.load();
    final script = config.pinChannelsScript;

    if (!File(script).existsSync()) {
      stderr.writeln('Pin script not found: $script');
      return 1;
    }

    print('Pinning Guix channels...');
    final process = await Process.start(
      'bash', [script],
      mode: ProcessStartMode.inheritStdio,
    );
    final exitCode = await process.exitCode;

    if (exitCode == 0) {
      // Show the pinned commit.
      final channelsFile = File(config.channelsPath);
      if (channelsFile.existsSync()) {
        final content = channelsFile.readAsStringSync();
        final match = RegExp(r'\(commit\s+"([a-f0-9]+)"\)').firstMatch(content);
        if (match != null) {
          print('Pinned to commit: ${match.group(1)}');
        }
      }
    }
    return exitCode;
  }
}
