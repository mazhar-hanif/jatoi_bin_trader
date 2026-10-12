import 'dart:js_interop';

@JS('location.reload')
external void _reloadPage();

void reloadCurrentPage() => _reloadPage();
