import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers the bundled fonts' SIL Open Font Licenses with Flutter's
/// license page (OFL requires the license to ship with the fonts).
void registerFontLicenses() {
  const fonts = {
    'cormorantgaramond': 'Cormorant Garamond',
    'courierprime': 'Courier Prime',
    'dancingscript': 'Dancing Script',
    'lora': 'Lora',
    'nunito': 'Nunito',
    'playfairdisplay': 'Playfair Display',
    'quicksand': 'Quicksand',
  };

  LicenseRegistry.addLicense(() async* {
    for (final entry in fonts.entries) {
      final text = await rootBundle.loadString('assets/fonts/licenses/OFL-${entry.key}.txt');
      yield LicenseEntryWithLineBreaks([entry.value], text);
    }
  });
}
