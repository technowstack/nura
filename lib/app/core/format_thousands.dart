/// Formats [n] with Indonesian dot thousands separators (6638 -> "6.638").
String formatThousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
