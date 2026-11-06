import '../theme_definition.dart';
import 'cafe_theme.dart';
import 'cottage_theme.dart';
import 'imperial_winter_theme.dart';
import 'midnight_theme.dart';
import 'sakura_theme.dart';
import 'starry_night_theme.dart';
import 'vintage_film_theme.dart';
import 'winter_love_theme.dart';

/// Themes beyond the default. Adding a theme = one file here + one catalog
/// entry in `backend/database/data/appearance_catalog.json`.
final List<ThemeDefinition> builtInThemes = [
  sakuraTheme,
  winterLoveTheme,
  midnightTheme,
  vintageFilmTheme,
  imperialWinterTheme,
  cottageTheme,
  cafeTheme,
  starryNightTheme,
];
