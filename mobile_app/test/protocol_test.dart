import 'package:flutter_test/flutter_test.dart';
import 'package:ppt_remote/protocol.dart';

void main() {
  test('wire names match the Mac receiver whitelist', () {
    expect(RemoteCommand.values.map((c) => c.wire),
        ['NEXT', 'PREV', 'START', 'RESUME', 'END', 'BLACK', 'WHITE']);
  });
}
