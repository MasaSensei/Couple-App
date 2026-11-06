import 'package:flutter/foundation.dart';

import 'photo_booth_template.dart';

/// Where a photo came from. Memory photos arrive already decrypted on the
/// device; neither kind is ever uploaded as-is.
enum PhotoSourceKind { gallery, memory }

/// One chosen photo: plaintext bytes that exist only in this app's memory.
@immutable
class PhotoBoothPhoto {
  const PhotoBoothPhoto({
    required this.id,
    required this.bytes,
    required this.source,
  });

  final String id;
  final Uint8List bytes;
  final PhotoSourceKind source;
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
