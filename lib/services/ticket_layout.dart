import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

import '../core/utils/formatters.dart';
import 'printer_preference_storage.dart';

/// Shared layout pieces for every printed receipt (table billing, cafe/POS,
/// tutup kas) so they read as one consistent design instead of three
/// independently hand-rolled layouts.
///
/// Bold is only ever applied via full-line [Ticket.text] calls here, never
/// inside a [Ticket.row] column: the plugin reinforces mid-line bold with a
/// bare-CR overstrike meant to overlap the same printed line on printers
/// that ignore inline ESC E, but this printer's firmware treats that CR as
/// a newline instead — turning the "reinforcement" into a literal
/// duplicate line. [grandTotal] gets its emphasis from size instead, which
/// is safe.
class TicketLayout {
  TicketLayout._();

  /// Characters per line for each ticket made by [create] — Font A width of
  /// its paper (32 on 58mm, 48 on 80mm). [Ticket] doesn't expose its paper
  /// size, so it's remembered here for [row]'s manual padding.
  static final _lineWidths = Expando<int>('ticketLineWidth');

  /// Creates a ticket at the paper width chosen in the printer settings
  /// (58mm / 80mm, see [PrinterPreferenceStorage]). Every printed receipt
  /// must be created through this so [row] pads to the right width.
  static Future<Ticket> create() async {
    final paperSize = await PrinterPreferenceStorage().getPaperSize();
    final ticket = await Ticket.create(paperSize);
    _lineWidths[ticket] = paperSize.charsPerLine(null);
    return ticket;
  }

  static void header(
    Ticket ticket, {
    required String businessName,
    required String businessAddress,
    required String invoiceNumber,
    required DateTime issuedAt,
    bool isReprint = false,
  }) {
    ticket.text(
      businessName,
      align: PrintAlign.center,
      style: const PrintTextStyle(bold: true),
    );
    ticket.text(businessAddress, align: PrintAlign.center);
    ticket.separator(char: '=', linesAfter: 1);
    ticket.text(
      invoiceNumber,
      align: PrintAlign.center,
      style: const PrintTextStyle(bold: true),
    );
    ticket.text(
      "${formatFullDate(issuedAt)}  ${formatClock(issuedAt)}",
      align: PrintAlign.center,
    );
    if (isReprint) {
      ticket.text(
        "*** PRINT ULANG ***",
        align: PrintAlign.center,
        style: const PrintTextStyle(bold: true),
      );
    }
    ticket.separator(char: '=', linesAfter: 1);
  }

  /// A plain label/value row — never bold, see class doc.
  ///
  /// Built as a single manually space-padded line, NOT via [Ticket.row]'s
  /// column positioning: that relies on an ESC $ absolute-position command
  /// that some printers (including the one a real printed sample surfaced
  /// this on) don't implement correctly — instead of just spacing, it
  /// printed a garbage placeholder glyph where the jump should be. Plain
  /// text has no such risk; every ESC/POS printer supports it identically.
  static void row(Ticket ticket, String label, String value) {
    // charsPerLine() bawaan paket ini untuk Font A sesuai kertas yang dipilih
    // (32 kolom di 58mm, 48 kolom di 80mm) - sama dengan lebar yang dipakai
    // separator() paket ini, jadi barisnya tetap sejajar. 48 kalau ticket
    // tidak dibuat lewat create().
    final lineWidth = _lineWidths[ticket] ?? 48;
    final combinedLength = label.length + value.length;

    if (combinedLength + 1 > lineWidth) {
      // Tidak muat satu baris - taruh value di baris sendiri rata kanan,
      // daripada dipotong atau bikin kolomnya meleset.
      ticket.text(label);
      ticket.text(value, align: PrintAlign.right);
      return;
    }

    final padding = ' ' * (lineWidth - combinedLength);
    ticket.text('$label$padding$value');
  }

  static void sectionTitle(Ticket ticket, String title) {
    ticket.feed(1);
    ticket.text(title, style: const PrintTextStyle(bold: true));
  }

  /// The final amount, set apart and enlarged so it's unmistakable —
  /// entirely via full-line text, never a row (see class doc).
  static void grandTotal(Ticket ticket, String label, int amount) {
    ticket.separator(char: '=', linesAfter: 1);
    ticket.text(label, style: const PrintTextStyle(bold: true));
    ticket.text(
      formatCurrency(amount),
      align: PrintAlign.right,
      style: const PrintTextStyle(
        bold: true,
        height: TextSize.size2,
        width: TextSize.size2,
      ),
    );
    ticket.separator(char: '=', linesAfter: 1);
  }

  static void footer(Ticket ticket, String cashierName) {
    row(ticket, "Kasir", cashierName);
    ticket.feed(1);
    ticket.text("Terima kasih atas kunjungan Anda", align: PrintAlign.center);
    ticket.feed(3);
    ticket.cut();
  }
}
