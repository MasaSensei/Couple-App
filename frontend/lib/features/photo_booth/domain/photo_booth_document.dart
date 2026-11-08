import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'photo_booth_template.dart';

/// Where a photo came from. Memory photos arrive already decrypted on the
/// device; neither kind is ever uploaded as-is.
enum PhotoSourceKind { gallery, memory }

/// How a photo sits inside its slot, like adjusting a picture in a frame.
///
/// [focus] is the point of the photo shown at the slot's centre, in 0–1
/// photo coordinates; [zoom] is relative to the smallest scale that fills the
/// slot. Both are resolution- and slot-independent, so a framing survives a
/// layout change; the renderer clamps it so a slot never shows an empty edge.
@immutable
class PhotoFraming {
  const PhotoFraming({this.focus = const Offset(0.5, 0.5), this.zoom = 1});

  static const centered = PhotoFraming();
  static const minZoom = 1.0;
  static const maxZoom = 4.0;

  final Offset focus;
  final double zoom;

  bool get isCentered => this == centered;

  PhotoFraming copyWith({Offset? focus, double? zoom}) => PhotoFraming(
    focus: focus ?? this.focus,
    zoom: (zoom ?? this.zoom).clamp(minZoom, maxZoom),
  );

  @override
  bool operator ==(Object other) =>
      other is PhotoFraming && other.focus == focus && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(focus, zoom);

  @override
  String toString() => 'PhotoFraming(focus: $focus, zoom: $zoom)';
}

/// One chosen photo: plaintext bytes that exist only in this app's memory.
@immutable
class PhotoBoothPhoto {
  const PhotoBoothPhoto({
    required this.id,
    required this.bytes,
    required this.source,
    this.framing = PhotoFraming.centered,
  });

  final String id;
  final Uint8List bytes;
  final PhotoSourceKind source;
  final PhotoFraming framing;

  PhotoBoothPhoto copyWith({PhotoFraming? framing}) => PhotoBoothPhoto(
    id: id,
    bytes: bytes,
    source: source,
    framing: framing ?? this.framing,
  );
}

/// The editor's state: everything needed to render the print.
@immutable
class PhotoBoothDocument {
  const PhotoBoothDocument({
    required this.template,
    this.photos = const [],
    this.caption = '',
    this.showDate = true,
    required this.date,
  });

  static const maxCaptionLength = 40;

  final PhotoBoothTemplate template;

  /// In slot order; extra photos beyond the template's slots are ignored.
  final List<PhotoBoothPhoto> photos;
  final String caption;
  final bool showDate;
  final DateTime date;

  bool get isComplete => photos.length >= template.photoCount;

  List<PhotoBoothPhoto> get slotted =>
      photos.take(template.photoCount).toList();

  PhotoBoothDocument copyWith({
    PhotoBoothTemplate? template,
    List<PhotoBoothPhoto>? photos,
    String? caption,
    bool? showDate,
    DateTime? date,
  }) => PhotoBoothDocument(
    template: template ?? this.template,
    photos: photos ?? this.photos,
    caption: caption ?? this.caption,
    showDate: showDate ?? this.showDate,
    date: date ?? this.date,
  );
}
