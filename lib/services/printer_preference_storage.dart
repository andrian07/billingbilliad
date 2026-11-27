import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

/// Persists which USB printer (by its Windows/OS identifier) the operator
/// picked to print receipts with — see [ReceiptPrinterService] and
/// [CashierSummaryPrinterService]. Without this, printing has to guess by
/// picking the first scan result, which can land on the wrong entry when
/// Windows lists several printers (virtual printers, or more than one real
/// printer set up for the same physical device with different drivers).
///
/// Also stores the receipt paper width (58mm or 80mm) the operator picked
/// in the same dialog; every printed ticket is laid out for that width.
class PrinterPreferenceStorage {
  static const _key = "selected_printer_identifier";
  static const _paperKey = "receipt_paper_size_mm";

  /// Paper widths the operator can choose from, in mm.
  static const supportedPaperWidths = [58, 80];

  /// Used when nothing has been saved yet — matches what every receipt was
  /// printed at before the setting existed.
  static const defaultPaperWidth = 80;

  Future<String?> getSelectedPrinterIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> setSelectedPrinterIdentifier(String? identifier) async {
    final prefs = await SharedPreferences.getInstance();
    if (identifier == null || identifier.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, identifier);
    }
  }

  /// Saved paper width in mm (58 or 80), [defaultPaperWidth] if unset.
  Future<int> getPaperWidth() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_paperKey);
    return supportedPaperWidths.contains(saved) ? saved! : defaultPaperWidth;
  }

  Future<void> setPaperWidth(int widthMm) async {
    if (!supportedPaperWidths.contains(widthMm)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_paperKey, widthMm);
  }

  /// The saved paper width as the printer package's [PaperSize].
  Future<PaperSize> getPaperSize() async =>
      (await getPaperWidth()) == 58 ? PaperSize.mm58 : PaperSize.mm80;
}
