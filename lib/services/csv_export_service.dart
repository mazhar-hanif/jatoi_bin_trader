String encodeCsvRows(List<List<String>> rows) =>
    rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
