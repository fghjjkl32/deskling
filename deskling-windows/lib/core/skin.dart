import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

enum PetPose {
  idle,
  walk,
  working,
  waiting,
  done,
  drag,
  fall;

  /// Poses to try, in order, when a skin has no image for this one. `idle` is always the last resort.
  List<PetPose> get fallbacks => switch (this) {
        PetPose.drag => const [PetPose.walk],
        PetPose.fall => const [PetPose.drag, PetPose.walk],
        _ => const [],
      };
}

/// One decoded animation: straight RGBA pixels per frame and each frame's duration in seconds.
class SpriteFrames {
  static const maxDimension = 4096;
  static const maxFrames = 240;
  static const maxTotalPixels = 64000000;
  static const _fallbackDelay = 0.1;

  const SpriteFrames({required this.width, required this.height, required this.pixels, required this.durations});

  final int width;
  final int height;
  final List<Uint8List> pixels;
  final List<double> durations;

  double get totalDuration => durations.fold(0, (sum, value) => sum + value);

  static SpriteFrames? load(String path, {int maxTotalPixels = SpriteFrames.maxTotalPixels}) {
    final Uint8List bytes;
    try {
      bytes = File(path).readAsBytesSync();
    } on FileSystemException {
      return null;
    }
    return decode(bytes, maxTotalPixels: maxTotalPixels);
  }

  static SpriteFrames? decode(Uint8List bytes, {int maxTotalPixels = SpriteFrames.maxTotalPixels}) {
    if (bytes.isEmpty) return null;
    final img.Decoder decoder;
    if (img.PngDecoder().isValidFile(bytes)) {
      decoder = img.PngDecoder();
    } else if (img.GifDecoder().isValidFile(bytes)) {
      decoder = img.GifDecoder();
    } else {
      return null;
    }
    try {
      final info = decoder.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) return null;
      if (info.width > maxDimension || info.height > maxDimension) return null;
      final count = info.numFrames.clamp(1, maxFrames);
      if (info.width * info.height * count > maxTotalPixels) return null;
      final image = decoder.decode(bytes);
      if (image == null) return null;
      final frames = image.frames.take(maxFrames).toList();
      return SpriteFrames(
        width: image.width,
        height: image.height,
        pixels: [
          for (final frame in frames)
            frame.convert(format: img.Format.uint8, numChannels: 4).getBytes(order: img.ChannelOrder.rgba),
        ],
        durations: [
          for (final frame in frames) frame.frameDuration < 20 ? _fallbackDelay : frame.frameDuration / 1000,
        ],
      );
    } on Object {
      return null;
    }
  }
}

class Skin {
  /// How much faster a borrowed walk cycle plays so that it reads as running.
  static const borrowedWalkSpeed = 2.0;

  const Skin({required this.id, required this.name, required this.height, required this.directory, required this.files});

  final String id;
  final String name;
  final double height;
  final String directory;
  final Map<PetPose, String> files;

  String pathFor(PetPose pose) => files[_resolved(pose)]!;

  /// Animation speed for a pose: a walk cycle standing in for `drag` or `fall` plays faster.
  double playbackSpeed(PetPose pose) =>
      pose != PetPose.walk && _resolved(pose) == PetPose.walk ? borrowedWalkSpeed : 1;

  PetPose _resolved(PetPose pose) =>
      [pose, ...pose.fallbacks].firstWhere((candidate) => files.containsKey(candidate), orElse: () => PetPose.idle);
}

class SkinLoader {
  static const defaultHeight = 96.0;
  static const minHeight = 16.0;
  static const maxHeight = 512.0;
  static const _extensions = {'.gif', '.png'};

  static Skin? load(String directory) {
    final List<File> entries;
    try {
      entries = Directory(directory).listSync().whereType<File>().toList()
        ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    } on FileSystemException {
      return null;
    }
    final files = <PetPose, String>{};
    for (final pose in PetPose.values) {
      for (final file in entries) {
        final name = p.basename(file.path);
        if (p.basenameWithoutExtension(name).toLowerCase() != pose.name) continue;
        if (!_extensions.contains(p.extension(name).toLowerCase())) continue;
        if (SpriteFrames.load(file.path) == null) continue;
        files[pose] = file.path;
        break;
      }
    }
    if (!files.containsKey(PetPose.idle)) return null;

    final id = p.basename(directory);
    var name = id;
    var height = defaultHeight;
    try {
      final json = jsonDecode(File(p.join(directory, 'skin.json')).readAsStringSync());
      if (json is Map<String, dynamic>) {
        final custom = json['name'];
        if (custom is String && custom.isNotEmpty) name = custom;
        final size = json['height'];
        if (size is num) height = size.toDouble().clamp(minHeight, maxHeight);
      }
    } on Object {
      // A missing or broken skin.json keeps the defaults.
    }
    return Skin(id: id, name: name, height: height, directory: directory, files: files);
  }

  static List<Skin> list(String root) {
    final List<Directory> folders;
    try {
      folders = Directory(root).listSync().whereType<Directory>().toList();
    } on FileSystemException {
      return [];
    }
    return folders.map((folder) => load(folder.path)).whereType<Skin>().toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}
