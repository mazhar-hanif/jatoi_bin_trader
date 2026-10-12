import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/business_rules.dart';
import '../models/models.dart';

Future<Uint8List> createOrderInvoicePdf(OrderModel order,
    {String vatNumber = ''}) async {
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text('Jatoi Bin Trader',
            style: const pw.TextStyle(
                fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.Text('Rice import & export · Bahrain'),
        if (vatNumber.isNotEmpty) pw.Text('VAT registration: $vatNumber'),
        pw.SizedBox(height: 24),
        pw.Text('INVOICE',
            style: const pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text('Order: ${order.id}'),
        pw.Text('Date: ${order.createdAt.toIso8601String().substring(0, 10)}'),
        pw.Text('Customer: ${order.userName}'),
        pw.Text('Phone: ${order.phone}'),
        pw.Text('Delivery address: ${order.address}'),
        if (order.deliveryDate != null)
          pw.Text(
              'Preferred delivery: ${order.deliveryDate!.toIso8601String().substring(0, 10)}'),
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: const ['Item', 'Bags', 'Unit (BHD)', 'Amount (BHD)'],
          data: [
            for (final item in order.items)
              [
                item.name,
                '${item.qty}',
                item.pricePerBag.toStringAsFixed(3),
                lineTotal(item.pricePerBag, item.qty).toStringAsFixed(3),
              ],
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Subtotal: BHD ${order.subtotal.toStringAsFixed(3)}'),
              pw.Text('VAT (10%): BHD ${order.vat.toStringAsFixed(3)}'),
              pw.Text(
                'Total: BHD ${order.total.toStringAsFixed(3)}',
                style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
        if (order.notes.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Order notes: ${order.notes}'),
        ],
      ],
    ),
  );
  return document.save();
}

Future<void> printOrderInvoice(OrderModel order,
    {String vatNumber = ''}) async {
  final bytes = await createOrderInvoicePdf(order, vatNumber: vatNumber);
  await Printing.layoutPdf(onLayout: (_) async => bytes);
}
