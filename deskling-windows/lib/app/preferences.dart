import 'package:shared_preferences/shared_preferences.dart';

/// The user's choices, kept between runs.
class Preferences {
  Preferences(this._store);

  static Future<Preferences> load() async => Preferences(await SharedPreferences.getInstance());

  final SharedPreferences _store;

  /// Null means the bundled default pet.
  String? get skinPath => _store.getString('skinPath');
  set skinPath(String? value) => value == null ? _store.remove('skinPath') : _store.setString('skinPath', value);

  double get sizeScale => _store.getDouble('sizeScale') ?? 1.0;
  set sizeScale(double value) => _store.setDouble('sizeScale', value);

  bool get bubblesEnabled => _store.getBool('bubblesEnabled') ?? true;
  set bubblesEnabled(bool value) => _store.setBool('bubblesEnabled', value);

  bool get petHidden => _store.getBool('petHidden') ?? false;
  set petHidden(bool value) => _store.setBool('petHidden', value);

  double? get petX => _store.getDouble('petX');
  set petX(double? value) => value == null ? _store.remove('petX') : _store.setDouble('petX', value);

  String? get monitorId => _store.getString('monitorId');
  set monitorId(String? value) => value == null ? _store.remove('monitorId') : _store.setString('monitorId', value);
}
