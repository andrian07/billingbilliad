import 'package:billiard_billing/core/utils/api_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final req = RequestOptions(path: '/Cafe/save_transaction_cafe');

  test('CodeIgniter HTML 500 shows status and DB error text', () {
    const html =
        '''<!DOCTYPE html><html><head><title>Database Error</title></head><body>
<div id="container"><h1>A Database Error Occurred</h1>
<p>Error Number: 1054</p><p>Unknown column 'promo_cafe_id' in 'field list'</p>
<p>INSERT INTO `transaction_cafe_detail` (`x`) VALUES (1)</p><p>Filename: models/Cafe_model.php</p></div></body></html>''';
    final e = DioException(
      requestOptions: req,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: req, statusCode: 500, data: html),
    );
    final msg = describeDioError(e);
    expect(
      msg,
      startsWith('Server error (HTTP 500): A Database Error Occurred'),
    );
    expect(msg, contains("Unknown column 'promo_cafe_id'"));
  });

  test('JSON error body uses its message', () {
    final e = DioException(
      requestOptions: req,
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: req,
        statusCode: 404,
        data: {'code': 0, 'result': 'Not found'},
      ),
    );
    expect(describeDioError(e), 'Server error (HTTP 404): Not found');
  });

  test('no response = cannot connect, names server', () {
    final e = DioException(
      requestOptions: req,
      type: DioExceptionType.connectionError,
    );
    final msg = describeDioError(e);
    expect(
      msg,
      contains(
        'Tidak dapat terhubung ke server http://localhost/billiard_backend',
      ),
    );
  });
}
