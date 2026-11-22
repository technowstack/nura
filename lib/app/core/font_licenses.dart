import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Test hook: forget the idempotency guard.
@visibleForTesting
void resetFontLicensesForTest() => _registered = false;

/// Makes the bundled fonts' OFL texts appear on Flutter's license page.
/// Flutter collects package licenses itself; fonts are not packages.
/// Idempotent; a missing asset skips its entry instead of throwing.
void registerFontLicenses({AssetBundle? bundle}) {
  if (_registered) return;
  _registered = true;
  final b = bundle ?? rootBundle;
  const fonts = {
    'Plus Jakarta Sans': 'assets/fonts/PlusJakartaSans/OFL.txt',
    'Scheherazade New': 'assets/fonts/ScheherazadeNew/OFL.txt',
  };
  fonts.forEach((name, asset) {
    LicenseRegistry.addLicense(() async* {
      try {
        yield LicenseEntryWithLineBreaks([name], await b.loadString(asset));
      } catch (e) {
        debugPrint('font license $asset not loaded: $e');
      }
    });
  });
}
