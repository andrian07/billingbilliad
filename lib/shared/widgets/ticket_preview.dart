import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/cafe_receipt.dart';
import '../../models/cashier_summary.dart';
import '../../models/receipt.dart';

/// Fallback for when no physical USB printer is connected — renders the same
/// content [TicketLayout]/the *_printer_service.dart files would send to a
/// real printer, as plain Flutter widgets styled to look like receipt paper,
/// so nota/struk content can still be checked during development or on a
/// machine with no printer attached. Shown automatically by the print
/// services when they can't find a printer (see *PrinterNotFoundException).
class TicketPreviewDialog extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const TicketPreviewDialog({
    super.key,
    required this.title,
    required this.children,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => TicketPreviewDialog(title: title, children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: const BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.print_disabled_rounded,
                  size: 15,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: 340, maxHeight: 560),
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SingleChildScrollView(
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.black,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              "TUTUP PREVIEW",
              style: TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors [TicketLayout]'s pieces (lib/services/ticket_layout.dart) but
/// returns [Widget]s instead of writing ESC/POS bytes to a [Ticket] — kept
/// visually in sync with that file on purpose, since both represent the
/// exact same printed content.
class TicketPreviewLayout {
  TicketPreviewLayout._();

  static List<Widget> header({
    required String businessName,
    required String businessAddress,
    required String invoiceNumber,
    required DateTime issuedAt,
    bool isReprint = false,
  }) {
    return [
      center(businessName, bold: true),
      center(businessAddress),
      separator(),
      center(invoiceNumber, bold: true),
      center("${formatFullDate(issuedAt)}  ${formatClock(issuedAt)}"),
      if (isReprint) center("*** PRINT ULANG ***", bold: true),
      separator(),
    ];
  }

  static Widget row(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label, style: style)),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: Text(value, textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }

  static Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  static Widget grandTotal(String label, int amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          separator(char: '='),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            formatCurrency(amount),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          separator(char: '='),
        ],
      ),
    );
  }

  static List<Widget> footer(String cashierName) {
    return [
      row("Kasir", cashierName),
      const SizedBox(height: 8),
      center("Terima kasih atas kunjungan Anda"),
    ];
  }

  static Widget center(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  /// A full-width horizontal rule approximating [Ticket.separator] — drawn
  /// as an actual line rather than repeated characters, since a fixed
  /// character count doesn't reliably reach the edge across every font's
  /// metrics (was leaving a visible gap on the right for '-'/'=' before).
  /// `=` is rendered slightly thicker to keep the two separator styles
  /// visually distinct, matching how the real ticket uses '=' for
  /// header/footer/grand-total boundaries and '-' for lighter section rules.
  static Widget separator({String char = '-'}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(height: char == '=' ? 2.5 : 1, color: Colors.black87),
    );
  }

  static Widget feed([double height = 6]) => SizedBox(height: height);
}

/// Builds preview content for each ticket type — mirrors the corresponding
/// `_build*Ticket()` in receipt_printer_service.dart/
/// cashier_summary_printer_service.dart line for line, since both represent
/// the exact same printed content and should be kept in sync.
class TicketPreviewContent {
  TicketPreviewContent._();

  static List<Widget> billing(Receipt receipt) {
    return [
      ...TicketPreviewLayout.header(
        businessName: receipt.businessName,
        businessAddress: receipt.businessAddress,
        invoiceNumber: receipt.invoiceNumber,
        issuedAt: receipt.date,
        isReprint: receipt.isReprint,
      ),
      TicketPreviewLayout.row("Meja", receipt.tableLabel),
      TicketPreviewLayout.row("Mulai", formatClock(receipt.startAt)),
      TicketPreviewLayout.row("Selesai", formatClock(receipt.endAt)),
      TicketPreviewLayout.row(
        "Durasi",
        formatDurationWords(receipt.totalDuration),
      ),
      if (receipt.periods.isNotEmpty) ...[
        TicketPreviewLayout.sectionTitle("Rincian Waktu"),
        for (final period in receipt.periods) ...[
          TicketPreviewLayout.row(
            period.label,
            formatCurrency(period.cost * 4),
          ),
          TicketPreviewLayout.row("  Durasi", formatDuration(period.duration)),
        ],
      ],
      TicketPreviewLayout.separator(),
      TicketPreviewLayout.row(
        "Subtotal",
        formatCurrency(receipt.subtotal * 4),
      ),
      if (receipt.promoName != null)
        TicketPreviewLayout.row("Promo", receipt.promoName!),
      if (receipt.discountAmount > 0)
        TicketPreviewLayout.row(
          "Diskon",
          "-${formatCurrency(receipt.discountAmount * 4)}",
        ),
      TicketPreviewLayout.grandTotal("GRAND TOTAL", receipt.grandTotal * 4),
      TicketPreviewLayout.row("Bayar", receipt.paymentMethod),
      ...TicketPreviewLayout.footer(receipt.cashierName),
    ];
  }

  static List<Widget> cafe(CafeReceipt receipt) {
    return [
      ...TicketPreviewLayout.header(
        businessName: receipt.businessName,
        businessAddress: receipt.businessAddress,
        invoiceNumber: receipt.invoiceNumber,
        issuedAt: receipt.date,
        isReprint: receipt.isReprint,
      ),
      if (receipt.table != null)
        TicketPreviewLayout.row("Meja", receipt.table!)
      else
        TicketPreviewLayout.row(
          "Customer",
          (receipt.customerName?.trim().isNotEmpty ?? false)
              ? receipt.customerName!.trim()
              : "-",
        ),
      TicketPreviewLayout.feed(),
      for (final item in receipt.items) ...[
        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (item.note != null) Text("  (${item.note})"),
        TicketPreviewLayout.row(
          "  ${item.quantity} x ${formatCurrency(item.price)}",
          formatCurrency(item.price * item.quantity),
        ),
        for (final addon in item.addons)
          TicketPreviewLayout.row(
            "  + ${addon.name} x${addon.quantity}",
            formatCurrency(addon.lineTotal),
          ),
      ],
      TicketPreviewLayout.separator(),
      TicketPreviewLayout.row("Subtotal", formatCurrency(receipt.subtotal)),
      if (receipt.discountAmount > 0)
        TicketPreviewLayout.row(
          "Diskon (${receipt.discountPercent}%)",
          "-${formatCurrency(receipt.discountAmount)}",
        ),
      if (receipt.tax > 0)
        TicketPreviewLayout.row("Pajak", formatCurrency(receipt.tax)),
      TicketPreviewLayout.grandTotal("TOTAL", receipt.total),
      TicketPreviewLayout.row("Bayar", receipt.paymentMethod),
      ...TicketPreviewLayout.footer(receipt.cashierName),
    ];
  }

  static List<Widget> cashierSummary(
    CashierClosingSummary summary,
    String cashierName,
  ) {
    final now = DateTime.now();

    return [
      TicketPreviewLayout.center("TUTUP KAS", bold: true),
      TicketPreviewLayout.center(formatFullDate(summary.businessDate)),
      TicketPreviewLayout.separator(char: '='),
      TicketPreviewLayout.row("Kasir", cashierName),
      TicketPreviewLayout.row(
        "Dicetak",
        "${formatFullDate(now)} ${formatClock(now)}",
      ),
      TicketPreviewLayout.sectionTitle("Billing"),
      TicketPreviewLayout.row("Jumlah Nota", "${summary.billing.invoiceCount}"),
      TicketPreviewLayout.row(
        "Total Transaksi",
        formatCurrency(summary.billing.totalTransaction * 4),
      ),
      for (final payment in summary.billing.byPayment)
        TicketPreviewLayout.row(
          "  ${payment.paymentName}",
          "${formatCurrency(payment.totalTransaction * 4)} (${payment.invoiceCount})",
        ),
      TicketPreviewLayout.sectionTitle("Cafe / POS"),
      TicketPreviewLayout.row("Jumlah Nota", "${summary.cafe.invoiceCount}"),
      TicketPreviewLayout.row(
        "Total Transaksi",
        formatCurrency(summary.cafe.totalTransaction),
      ),
      for (final payment in summary.cafe.byPayment)
        TicketPreviewLayout.row(
          "  ${payment.paymentName}",
          "${formatCurrency(payment.totalTransaction)} (${payment.invoiceCount})",
        ),
      TicketPreviewLayout.separator(),
      TicketPreviewLayout.row("Total Nota", "${summary.totalInvoiceCount}"),
      TicketPreviewLayout.grandTotal(
        "GRAND TOTAL",
        summary.billing.totalTransaction * 4 + summary.cafe.totalTransaction,
      ),
    ];
  }

  static List<Widget> cafeItemsSold(
    CashierClosingSummary summary,
    String cashierName,
  ) {
    final now = DateTime.now();

    final rows = <Widget>[
      TicketPreviewLayout.center("ITEM CAFE TERJUAL", bold: true),
      TicketPreviewLayout.center(formatFullDate(summary.businessDate)),
      TicketPreviewLayout.separator(char: '='),
      TicketPreviewLayout.row("Kasir", cashierName),
      TicketPreviewLayout.row(
        "Dicetak",
        "${formatFullDate(now)} ${formatClock(now)}",
      ),
      TicketPreviewLayout.separator(),
    ];

    if (summary.cafeItems.isEmpty) {
      rows.add(TicketPreviewLayout.center("Tidak ada penjualan cafe hari ini"));
    } else {
      var totalQty = 0;
      for (final item in summary.cafeItems) {
        rows.add(TicketPreviewLayout.row(item.productName, "${item.quantity}"));
        totalQty += item.quantity;
      }
      rows.add(TicketPreviewLayout.separator());
      rows.add(TicketPreviewLayout.row("Total Item", "$totalQty"));
    }

    return rows;
  }
}
