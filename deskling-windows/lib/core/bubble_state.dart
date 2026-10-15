/// Decides what the speech bubble shows, remembering a click dismissal until the text changes.
class BubbleState {
  /// Clicks this soon after a bubble appears are ignored, so one already on its way cannot dismiss it unseen.
  static const clickGuard = Duration(milliseconds: 500);

  String? _shown;
  String? _dismissed;
  bool _visible = false;
  DateTime _ignoreClicksUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// The text on screen, or null when the bubble is hidden.
  String? get visibleText => _visible ? _shown : null;

  /// Passing null hides the bubble and forgets a dismissal.
  void update(String? text, DateTime now) {
    if (text == null) {
      _dismissed = null;
      _shown = null;
      _visible = false;
      return;
    }
    if (text == _dismissed) return;
    _dismissed = null;
    if (text != _shown || !_visible) _ignoreClicksUntil = now.add(clickGuard);
    _shown = text;
    _visible = true;
  }

  void click(DateTime now) {
    if (!_visible || now.isBefore(_ignoreClicksUntil)) return;
    _dismissed = _shown;
    _visible = false;
  }

  /// A new attention request or Stop shows the same text again after a dismissal.
  void clearDismissal() => _dismissed = null;
}
