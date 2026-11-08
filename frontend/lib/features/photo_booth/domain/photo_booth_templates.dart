import 'package:flutter/material.dart';

import 'photo_booth_template.dart';

/// Built-in layouts. Adding one = a new entry here + one in
/// `backend/database/data/appearance_catalog.json` (a test keeps them in sync).
abstract final class PhotoBoothTemplates {
  static const _cream = Color(0xFFFBF7F0);
  static const _ink = Color(0xFF3B2F2F);

  static Rect _r(double l, double t, double w, double h) =>
      Rect.fromLTWH(l, t, w, h);

  static final classic2 = PhotoBoothTemplate(
    key: 'classic_2',
    name: 'Classic 2-frame',
    canvasSize: const Size(1200, 1600),
    slots: [_r(80, 80, 1040, 600), _r(80, 720, 1040, 600)],
    captionArea: _r(80, 1360, 1040, 180),
    frame: FrameStyle.classic,
    paper: _cream,
    ink: _ink,
    slotRadius: 24,
    captionFont: 'PlayfairDisplay',
  );

  static final classic3 = PhotoBoothTemplate(
    key: 'classic_3',
    name: 'Classic 3-frame',
    canvasSize: const Size(1200, 1800),
    slots: [
      _r(80, 80, 1040, 440),
      _r(80, 560, 1040, 440),
      _r(80, 1040, 1040, 440),
    ],
    captionArea: _r(80, 1520, 1040, 220),
    frame: FrameStyle.classic,
    paper: _cream,
    ink: _ink,
    slotRadius: 20,
    captionFont: 'PlayfairDisplay',
  );

  static final classic4 = PhotoBoothTemplate(
    key: 'classic_4',
    name: 'Classic 4-frame',
    canvasSize: const Size(1400, 1600),
    slots: [
      _r(80, 80, 600, 600),
      _r(720, 80, 600, 600),
      _r(80, 720, 600, 600),
      _r(720, 720, 600, 600),
    ],
    captionArea: _r(80, 1360, 1240, 180),
    frame: FrameStyle.classic,
    paper: _cream,
    ink: _ink,
    slotRadius: 20,
    captionFont: 'Nunito',
  );

  static final verticalStrip = PhotoBoothTemplate(
    key: 'vertical_strip',
    name: 'Vertical photo strip',
    canvasSize: const Size(600, 1800),
    slots: [
      _r(50, 50, 500, 360),
      _r(50, 440, 500, 360),
      _r(50, 830, 500, 360),
      _r(50, 1220, 500, 360),
    ],
    captionArea: _r(50, 1600, 500, 160),
    frame: FrameStyle.strip,
    paper: Colors.white,
    ink: _ink,
    captionFont: 'Nunito',
  );

  static final polaroid = PhotoBoothTemplate(
    key: 'polaroid',
    name: 'Polaroid',
    canvasSize: const Size(1080, 1300),
    slots: [_r(70, 70, 940, 940)],
    captionArea: _r(70, 1050, 940, 200),
    frame: FrameStyle.polaroid,
    paper: const Color(0xFFFFFEFA),
    ink: const Color(0xFF2E2A28),
    captionFont: 'DancingScript',
  );

  static final vintageFilm = PhotoBoothTemplate(
    key: 'vintage_film',
    name: 'Vintage Film',
    canvasSize: const Size(900, 1800),
    slots: [
      _r(150, 120, 600, 450),
      _r(150, 640, 600, 450),
      _r(150, 1160, 600, 450),
    ],
    captionArea: _r(150, 1640, 600, 120),
    frame: FrameStyle.film,
    paper: const Color(0xFF1E1A17),
    ink: const Color(0xFFF1E3C8),
    captionFont: 'CourierPrime',
  );

  static final romanticFrame = PhotoBoothTemplate(
    key: 'romantic_frame',
    name: 'Romantic Frame',
    canvasSize: const Size(1200, 1600),
    slots: [_r(120, 160, 960, 560), _r(120, 760, 960, 560)],
    captionArea: _r(120, 1360, 960, 180),
    frame: FrameStyle.romantic,
    paper: const Color(0xFFFFF1F4),
    ink: const Color(0xFF7A2E45),
    slotRadius: 36,
    captionFont: 'DancingScript',
  );

  static final winterFrame = PhotoBoothTemplate(
    key: 'winter_frame',
    name: 'Winter Frame',
    canvasSize: const Size(1200, 1800),
    slots: [
      _r(120, 140, 960, 420),
      _r(120, 600, 960, 420),
      _r(120, 1060, 960, 420),
    ],
    captionArea: _r(120, 1520, 960, 200),
    frame: FrameStyle.winter,
    paper: const Color(0xFFF2F7FC),
    ink: const Color(0xFF1D3A55),
    slotRadius: 16,
    captionFont: 'CormorantGaramond',
  );

  static final List<PhotoBoothTemplate> all = List.unmodifiable([
    classic2,
    classic3,
    classic4,
    verticalStrip,
    polaroid,
    vintageFilm,
    romanticFrame,
    winterFrame,
  ]);

  static PhotoBoothTemplate? byKey(String key) =>
      all.where((t) => t.key == key).firstOrNull;
}
