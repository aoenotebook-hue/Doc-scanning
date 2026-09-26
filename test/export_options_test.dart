import 'package:flutter_test/flutter_test.dart';
import 'package:scan_and_open/core/models.dart';

void main() {
  test('export defaults are PDF, A4, standard, and 200 DPI', () {
    const value = ExportOptions();
    expect(value.format, ExportFormat.pdf); expect(value.pageSize, PageSize.a4);
    expect(value.resolution, OutputResolution.standard); expect(value.dpi, 200);
  });
  test('PNG remains independent of meaningless JPEG quality UI', () {
    const value = ExportOptions(format: ExportFormat.png);
    expect(value.format, ExportFormat.png);
  });
}
