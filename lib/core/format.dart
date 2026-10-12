const double vatRate = 0.10; // Bahrain VAT - confirm current rate before launch

/// BHD uses 3 decimal places.
String bhd(double v) => 'BHD ${v.toStringAsFixed(3)}';

String fmtDate(DateTime? d) => d == null
    ? '-'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
