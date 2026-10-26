import 'session_tracker.dart';
import 'skin.dart';

enum Language {
  korean,
  english;

  /// Follows the first preferred language, given as locale tags such as `ko-KR` or `ko_KR`.
  static Language current(List<String> preferred) =>
      preferred.isNotEmpty && preferred.first.toLowerCase().startsWith('ko') ? Language.korean : Language.english;
}

enum Txt {
  statusConnected('Claude Code: 연결됨', 'Claude Code: Connected'),
  statusNotConnected('Claude Code: 연결 안 됨', 'Claude Code: Not connected'),
  connect('Claude Code 연결하기', 'Connect to Claude Code'),
  disconnect('연결 해제하기', 'Disconnect'),
  wsl('WSL', 'WSL'),
  wslNone('WSL 없음', 'No WSL'),
  wslUnreadable('읽을 수 없음', 'Unavailable'),
  skin('스킨', 'Skin'),
  defaultSkin('기본 펫', 'Default pet'),
  openSkinsFolder('스킨 폴더 열기', 'Open Skins Folder'),
  size('크기', 'Size'),
  sizeSmall('작게', 'Small'),
  sizeMedium('보통', 'Medium'),
  sizeLarge('크게', 'Large'),
  showBubbles('말풍선 보이기', 'Show Speech Bubbles'),
  hidePet('펫 숨기기', 'Hide Pet'),
  showPet('펫 보이기', 'Show Pet'),
  launchAtLogin('로그인할 때 실행하기', 'Launch at Login'),
  quit('종료하기', 'Quit Deskling'),
  waitingFallback('입력을 기다리고 있습니다.', 'Waiting for your input.'),
  doneMessage('작업을 마쳤습니다.', 'Finished working.'),
  sessions('세션', 'Sessions'),
  noSessions('세션 없음', 'No sessions'),
  unnamedProject('이름 없음', 'Unnamed'),
  stateIdle('쉬는 중', 'Idle'),
  stateWorking('작업 중', 'Working'),
  stateWaiting('입력 대기', 'Waiting for input'),
  stateDone('작업 완료', 'Finished'),
  invalidSettingsTitle('settings.json을 읽을 수 없습니다.', 'Could not read settings.json.'),
  invalidSettingsBody(
    '파일을 수정하지 않았습니다. 넣어야 할 설정을 클립보드에 복사했습니다. 아래 파일에 직접 붙여 넣어야 합니다.',
    'The file was not changed. The settings to add were copied to the clipboard. Paste them into the file below.',
  ),
  connectFailed('Claude Code와 연결하지 못했습니다.', 'Could not connect to Claude Code.'),
  loginItemFailed('로그인 항목을 바꾸지 못했습니다.', 'Could not change the login item.'),
  alreadyRunning(
    'Deskling이 이미 실행 중입니다. 새로 받은 버전을 쓰려면 작업 표시줄 트레이의 Deskling 메뉴에서 종료한 다음 다시 실행하면 됩니다.',
    'Deskling is already running. To use a newly downloaded version, quit it from its tray menu first, then start it again.',
  ),
  missingResources('기본 펫 그림을 찾을 수 없습니다.', 'The default pet images are missing.');

  const Txt(this.korean, this.english);
  final String korean;
  final String english;

  String of(Language language) => language == Language.korean ? korean : english;

  /// A menu item that connects or disconnects one WSL distribution.
  static String wslTarget(String distro, {required bool connected, required Language language}) =>
      '$distro: ${(connected ? Txt.disconnect : Txt.connect).of(language)}';
}

class PetPresentation {
  static const maxMessageLength = 120;
  static const maxProjectLength = 40;
  static const maxTitleLength = 60;

  static PetPose pose(PetState state, {required bool isWalking, bool isHeld = false, bool isFalling = false}) {
    if (isHeld) return PetPose.drag;
    if (isFalling) return PetPose.fall;
    switch (state) {
      case PetState.idle:
        return isWalking ? PetPose.walk : PetPose.idle;
      case PetState.working:
        return PetPose.working;
      case PetState.waiting:
        return PetPose.waiting;
      case PetState.done:
        return PetPose.done;
    }
  }

  /// The bubble text: an optional project line, an optional title line, then the message, one per line.
  static String? bubble(PetDisplay display, Language language) {
    final String body;
    switch (display.state) {
      case PetState.idle:
      case PetState.working:
        return null;
      case PetState.waiting:
        final message = _collapseWhitespace(display.message ?? '');
        body = message.isEmpty ? Txt.waitingFallback.of(language) : _truncate(message, maxMessageLength);
      case PetState.done:
        body = Txt.doneMessage.of(language);
    }
    final lines = <String>[];
    final project = display.projectName;
    if (project != null && project.isNotEmpty) lines.add(_truncate(project, maxProjectLength));
    final heading = title(display.title);
    if (heading != null) lines.add(heading);
    lines.add(body);
    return lines.join('\n');
  }

  /// A prompt shortened to one line, or null when there is nothing to show.
  static String? title(String? prompt) {
    final text = _collapseWhitespace(prompt ?? '');
    return text.isEmpty ? null : _truncate(text, maxTitleLength);
  }

  static String sessionLine(SessionSummary summary, Language language) {
    final state = switch (summary.state) {
      PetState.idle => Txt.stateIdle,
      PetState.working => Txt.stateWorking,
      PetState.waiting => Txt.stateWaiting,
      PetState.done => Txt.stateDone,
    };
    final name = summary.projectName;
    final project = name == null || name.isEmpty ? Txt.unnamedProject.of(language) : name;
    return '${_truncate(project, maxProjectLength)} — ${state.of(language)}';
  }

  static String _collapseWhitespace(String text) => text.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).join(' ');

  static String _truncate(String text, int limit) {
    final runes = text.runes.toList();
    return runes.length > limit ? '${String.fromCharCodes(runes.take(limit))}…' : text;
  }
}
