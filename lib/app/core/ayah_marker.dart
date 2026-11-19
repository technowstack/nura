/// Converts [n] to Arabic-Indic digits (U+0660 to U+0669).
String toArabicIndic(int n) => n
    .toString()
    .split('')
    .map((d) => String.fromCharCode(0x0660 + int.parse(d)))
    .join();

/// Appends the ayah end marker. Only trailing ASCII U+0020 of [arab] is
/// stripped; the text is otherwise untouched.
String ayahDisplayText(String arab, int ayahNumber) {
  var end = arab.length;
  while (end > 0 && arab.codeUnitAt(end - 1) == 0x20) {
    end--;
  }
  return '${arab.substring(0, end)} ۝${toArabicIndic(ayahNumber)}';
}
