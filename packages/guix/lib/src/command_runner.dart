import 'package:args/command_runner.dart';
import 'package:guix/src/commands/init_command.dart';
import 'package:guix/src/commands/setup_command.dart';
import 'package:guix/src/commands/shell_command.dart';
import 'package:guix/src/commands/build_command.dart';
import 'package:guix/src/commands/doctor_command.dart';
import 'package:guix/src/commands/pin_command.dart';
import 'package:guix/src/commands/clean_command.dart';

class GuixCommandRunner extends CommandRunner<int> {
  GuixCommandRunner()
      : super(
          'guix_dart',
          'Reproducible Dart and Flutter builds with GNU Guix.\n\n'
          'Wraps the guix-flutter-scripts shell scripts with a discoverable CLI.\n'
          'Install: dart pub global activate guix',
        ) {
    argParser
      ..addFlag('verbose', abbr: 'v', help: 'Show underlying commands')
      ..addFlag('version', negatable: false, help: 'Print version and exit');

    addCommand(InitCommand());
    addCommand(SetupCommand());
    addCommand(ShellCommand());
    addCommand(BuildCommand());
    addCommand(DoctorCommand());
    addCommand(PinCommand());
    addCommand(CleanCommand());
  }

  @override
  Future<int?> run(Iterable<String> args) async {
    final results = parse(args);
    if (results['version'] == true) {
      print('guix_dart 0.1.0');
      return 0;
    }
    return await runCommand(results);
  }
}
