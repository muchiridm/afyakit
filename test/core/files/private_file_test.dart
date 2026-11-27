import 'dart:convert';
import 'package:afyakit/features/clinical/prescriptions/prescriptions_service.dart';
import 'package:afyakit/features/records/documents/document_upload_service.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/files/private_file.dart';

class ByteAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions) respond;
  ByteAdapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

class FakeUploader extends SignedDocumentUploadService {
  int calls = 0;
  void Function()? after;
  @override
  Future<void> upload(
    DocumentUploadReservation reservation,
    PickedDocumentFile file,
  ) async {
    calls++;
    expect(reservation.headers['x-goog-if-generation-match'], '0');
    after?.call();
  }
}

void main() {
  final uri = Uri.parse(
    'https://synthetic.invalid/api/tenant/documents/id/storage-download',
  );
  ResponseBody pdf() => ResponseBody.fromBytes(
    '%PDF-synthetic'.codeUnits,
    200,
    headers: {
      Headers.contentTypeHeader: ['application/pdf'],
    },
  );
  test(
    'private download uses authenticated API bytes, never a bearer download URL',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = ByteAdapter((options) async {
        expect(options.method, 'POST');
        expect(options.responseType, ResponseType.bytes);
        expect(options.extra['sensitiveResponse'], true);
        return pdf();
      });
      final file = await downloadPrivateFile(
        AfyaKitClient(dio),
        uri,
        'test.pdf',
        () => true,
      );
      expect(String.fromCharCodes(file.bytes), '%PDF-synthetic');
      expect(file.contentType, 'application/pdf');
    },
  );
  test(
    'context changes reject stale asynchronous bytes and prevent subsequent requests',
    () async {
      var current = true;
      var requests = 0;
      final pending = Completer<ResponseBody>();
      final dio = Dio()
        ..httpClientAdapter = ByteAdapter((_) {
          requests++;
          return pending.future;
        });
      final result = downloadPrivateFile(
        AfyaKitClient(dio),
        uri,
        'test.pdf',
        () => current,
      );
      await Future<void>.delayed(Duration.zero);
      current = false;
      final assertion = expectLater(result, throwsStateError);
      pending.complete(pdf());
      await assertion;
      await expectLater(
        downloadPrivateFile(AfyaKitClient(dio), uri, 'test.pdf', () => current),
        throwsStateError,
      );
      expect(requests, 1);
    },
  );
  test(
    'invalid payloads and provider errors produce fixed messages without sensitive content',
    () async {
      for (final response in [
        ResponseBody.fromString('SYNTHETIC_SECRET', 503),
        ResponseBody.fromString(
          'SYNTHETIC_SECRET',
          200,
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      ]) {
        final dio = Dio()
          ..httpClientAdapter = ByteAdapter((_) async => response);
        await expectLater(
          downloadPrivateFile(AfyaKitClient(dio), uri, 'test.pdf', () => true),
          throwsA(
            predicate(
              (e) =>
                  e.toString().contains('Private file unavailable') &&
                  !e.toString().contains('SYNTHETIC_SECRET'),
            ),
          ),
        );
      }
    },
  );
  test(
    'prescription upload reserves, uses shared signed PUT and finalizes only in its original context',
    () async {
      var current = true;
      var finalized = 0;
      final uploader = FakeUploader();
      final dio = Dio()
        ..httpClientAdapter = ByteAdapter((options) async {
          if (options.uri.path.endsWith('/storage-access')) {
            return ResponseBody.fromString(
              jsonEncode({
                'storage_access': {
                  'tenant_id': 'afya',
                  'app_id': 'dawapap',
                  'profile_id': 'p',
                  'prescription_id': 'reserved',
                  'document_id': 'reserved',
                  'storage_path':
                      'tenants/afya/apps/dawapap/prescriptions/reserved/original.pdf',
                  'upload_url': 'https://synthetic.invalid/put',
                  'upload_method': 'PUT',
                  'upload_headers': {
                    'content-type': 'application/pdf',
                    'content-length': '6',
                    'x-goog-if-generation-match': '0',
                  },
                  'finalize_by': DateTime.now()
                      .add(const Duration(minutes: 30))
                      .toIso8601String(),
                },
              }),
              200,
              headers: {
                Headers.contentTypeHeader: ['application/json'],
              },
            );
          }
          finalized++;
          expect((options.data as Map)['prescription_id'], 'reserved');
          return ResponseBody.fromString(
            jsonEncode({
              'prescription': {
                'prescription_id': 'reserved',
                'profile_id': 'p',
                'app_id': 'dawapap',
                'file_name': 'test.pdf',
                'storage_path': 'synthetic',
                'is_active': true,
                'status': 'uploaded',
              },
            }),
            200,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
      final service = PrescriptionsService(
        appId: 'dawapap',
        api: AfyaKitClient(dio),
        routes: AfyaKitRoutes('afya'),
        isCurrent: () => current,
        uploader: uploader,
      );
      final file = PickedPrescriptionFile(
        fileName: 'test.pdf',
        extension: 'pdf',
        bytes: Uint8List.fromList('%PDF-x'.codeUnits),
      );
      await service.uploadAndCreate(tenantId: 'afya', profileId: 'p', file: file);
      expect(finalized, 1);
      expect(uploader.calls, 1);
      uploader.after = () => current = false;
      await expectLater(
        service.uploadAndCreate(tenantId: 'afya', profileId: 'p', file: file),
        throwsStateError,
      );
      expect(finalized, 1);
    },
  );
}
