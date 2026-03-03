import 'dart:io';
import 'package:guix/src/command_runner.dart';

Future<void> main(List<String> args) async {
  final runner = GuixCommandRunner();
  try {
    final exitCode = await runner.run(args);
    exit(exitCode ?? 0);
  } on Exception catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
