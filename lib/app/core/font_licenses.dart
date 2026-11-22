import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Makes the bundled fonts' OFL texts appear on Flutter's license page.
/// Flutter collects package licenses itself; fonts are not packages.
void registerFontLicenses({AssetBundle? bundle}) {
  final b = bundle ?? rootBundle;
  const fonts = {
    'Plus Jakarta Sans': 'assets/fonts/PlusJakartaSans/OFL.txt',
    'Scheherazade New': 'assets/fonts/ScheherazadeNew/OFL.txt',
  };
  fonts.forEach((name, asset) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([name], await b.loadString(asset));
    });
  });
}
