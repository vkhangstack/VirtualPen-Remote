/// Wire protocol shared with `mac_receiver`. Keep in sync with
/// `Command` in mac_receiver/Sources/PPTReceiver/KeySender.swift.
enum RemoteCommand {
  next('NEXT'),
  prev('PREV'),
  start('START'),
  resume('RESUME'),
  end('END'),
  black('BLACK'),
  white('WHITE');

  const RemoteCommand(this.wire);
  final String wire;
}

const kTcpPort = 50555;
const kBonjourType = '_pptremote._tcp';
const kBleServiceUuid = '7A1C0001-5B8E-4C3A-9F2D-1E6B8A4C0D01';
const kBleCommandUuid = '7A1C0002-5B8E-4C3A-9F2D-1E6B8A4C0D01';
