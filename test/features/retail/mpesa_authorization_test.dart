import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/retail/mpesa/services/mpesa_service.dart';
import 'package:afyakit/features/retail/mpesa/models/mpesa_payment.dart';
import 'package:afyakit/features/retail/mpesa/models/mpesa_stk_draft.dart';
import 'package:afyakit/features/retail/mpesa/providers/payment_access_provider.dart';
import 'package:afyakit/features/retail/payments/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/payments/services/zoho_payments_service.dart';
import 'package:afyakit/features/retail/payments/models/zoho_payment_dtos.dart';

MpesaPayment payment([String status = 'created']) => MpesaPayment(
  id: 'synthetic',
  status: status,
  amount: 10,
  currency: 'KES',
  updatedAt: DateTime(2026),
);

class FakePayments extends ZohoPaymentsService {
  FakePayments()
    : super(api: AfyaKitClient(Dio()), routes: AfyaKitRoutes('afya'));
  @override
  Future<ListInvoicePaymentsResult> listInvoicePaymentsWithBalance(
    String id, {
    int perPage = 100,
    int page = 1,
  }) async => ListInvoicePaymentsResult(
    payments: [],
    invoice: InvoiceBalanceSummary(invoiceId: id, balance: 100),
  );
}

class FakeMpesa extends MpesaService {
  FakeMpesa() : super(AfyaKitClient(Dio()), AfyaKitRoutes('afya'));
  final drafts = <MpesaStkInitiateDraft>[];
  Completer<MpesaPayment>? pending;
  bool denied = false;
  MpesaPayment? resultOverride;
  @override
  Future<MpesaPayment> getPaymentStatus(String paymentId) async =>
      resultOverride ?? payment();
  @override
  Future<MpesaPayment> initiateAndWait({
    required MpesaStkInitiateDraft draft,
    Duration timeout = const Duration(minutes: 2),
    Duration firstDelay = const Duration(milliseconds: 1200),
    Duration interval = const Duration(seconds: 2),
    MpesaTick? onTick,
    bool Function()? isCurrent,
  }) async {
    drafts.add(draft);
    if (denied)
      throw DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 404),
      );
    final result = pending == null
        ? (resultOverride ?? payment())
        : await pending!.future;
    if (isCurrent?.call() != false) onTick?.call(result);
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const context = (uid: 'one', tenant: 'afya', app: 'dawapap', active: true);
  Future<void> ready(ProviderContainer container) async {
    container.read(paymentControllerProvider('789'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  ProviderContainer setup(FakeMpesa mpesa) => ProviderContainer(
    overrides: [
      paymentContextProvider.overrideWithValue(context),
      zohoPaymentsServiceProvider.overrideWith((ref) async => FakePayments()),
      mpesaServiceProvider.overrideWith((ref) async => mpesa),
      mpesaEligibilityProvider('789').overrideWith((ref) async => true),
    ],
  );

  test(
    'unverified success, conflicts, uncertain and legacy failure retain the same attempt',
    () async {
      for (final result in [
        payment('stk_success'),
        payment('stk_failed'),
        MpesaPayment(
          id: 'synthetic',
          status: 'stk_initiated',
          amount: 10,
          currency: 'KES',
          updatedAt: DateTime(2026),
          verificationStatus: 'conflict',
        ),
        MpesaPayment(
          id: 'synthetic',
          status: 'created',
          amount: 10,
          currency: 'KES',
          updatedAt: DateTime(2026),
          dispatchState: 'uncertain',
        ),
      ]) {
        final fake = FakeMpesa()..resultOverride = result;
        final container = setup(fake);
        await ready(container);
        final controller = container.read(
          paymentControllerProvider('789').notifier,
        );
        expect(
          await controller.payViaMpesaStk(phone: '0712345678', amount: 10),
          false,
        );
        expect(
          container.read(paymentControllerProvider('789')).mpesaLastPayment,
          result,
        );
        expect(
          await controller.payViaMpesaStk(phone: '0712345678', amount: 10),
          false,
        );
        expect(fake.drafts[0].clientRequestId, fake.drafts[1].clientRequestId);
        await controller.refresh();
        expect(
          container.read(paymentControllerProvider('789')).mpesaLastPayment,
          result,
        );
        expect(result.isPaymentComplete, false);
        expect(
          result.isTerminal,
          true,
        ); // stops bounded polling, never means settled
        expect(result.statusMessage, isNot(contains('verified and recorded')));
        container.dispose();
      }
    },
  );

  test(
    'whole shillings, alternative phone and stable attempt ID; concurrent clicks do not dispatch twice',
    () async {
      final fake = FakeMpesa();
      final container = setup(fake);
      addTearDown(container.dispose);
      await ready(container);
      final controller = container.read(
        paymentControllerProvider('789').notifier,
      );
      expect(
        await controller.payViaMpesaStk(phone: '0712345678', amount: 10.5),
        false,
      );
      expect(fake.drafts, isEmpty);
      await controller.payViaMpesaStk(phone: '0712345678', amount: 10);
      await controller.payViaMpesaStk(phone: '0712345678', amount: 10);
      expect(fake.drafts.length, 2);
      expect(fake.drafts[0].clientRequestId, fake.drafts[1].clientRequestId);
      expect(fake.drafts[0].phone, '254712345678');
      fake.pending = Completer<MpesaPayment>();
      final waiting = controller.payViaMpesaStk(
        phone: '0712345678',
        amount: 10,
      );
      expect(
        await controller.payViaMpesaStk(phone: '0712345678', amount: 10),
        false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(fake.drafts.length, 3);
      fake.pending!.complete(payment());
      await waiting;
    },
  );

  test(
    'user/tenant/app/membership changes dispose sensitive state and ignore in-flight completion',
    () async {
      for (final next in [
        (uid: 'two', tenant: 'afya', app: 'dawapap', active: true),
        (uid: 'one', tenant: 'other', app: 'dawapap', active: true),
        (uid: 'one', tenant: 'afya', app: 'other', active: true),
        (uid: 'one', tenant: 'afya', app: 'dawapap', active: false),
        (uid: null, tenant: 'afya', app: 'dawapap', active: false),
      ]) {
        final fake = FakeMpesa()..pending = Completer<MpesaPayment>();
        final container = setup(fake);
        await ready(container);
        final old = container.read(paymentControllerProvider('789').notifier);
        final waiting = old.payViaMpesaStk(phone: '0712345678', amount: 10);
        await Future<void>.delayed(Duration.zero);
        container.updateOverrides([
          paymentContextProvider.overrideWithValue(next),
          zohoPaymentsServiceProvider.overrideWith(
            (ref) async => FakePayments(),
          ),
          mpesaServiceProvider.overrideWith((ref) async => fake),
          mpesaEligibilityProvider('789').overrideWith((ref) async => true),
        ]);
        final fresh = container.read(paymentControllerProvider('789'));
        expect(fresh.mpesaLastPayment, isNull);
        fake.pending!.complete(payment('stk_success'));
        expect(await waiting, false);
        expect(
          container.read(paymentControllerProvider('789')).mpesaLastPayment,
          isNull,
        );
        container.dispose();
      }
    },
  );

  test('access denial clears cached payment state', () async {
    final fake = FakeMpesa();
    final container = setup(fake);
    addTearDown(container.dispose);
    await ready(container);
    final controller = container.read(
      paymentControllerProvider('789').notifier,
    );
    await controller.payViaMpesaStk(phone: '0712345678', amount: 10);
    expect(controller.publicState.mpesaLastPayment, isNotNull);
    fake.denied = true;
    await controller.payViaMpesaStk(phone: '0712345678', amount: 10);
    expect(controller.publicState.mpesaLastPayment, isNull);
    expect(controller.publicState.payments, isEmpty);
    expect(controller.publicState.invoiceSummary, isNull);
  });

  test(
    'real polling service rejects a stale network response before callbacks',
    () async {
      final dio = Dio();
      final pending = Completer<Response<dynamic>>();
      int requests = 0;
      int ticks = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            requests++;
            final result = await pending.future;
            handler.resolve(
              Response(
                requestOptions: options,
                data: result.data,
                statusCode: 200,
              ),
            );
          },
        ),
      );
      final service = MpesaService(AfyaKitClient(dio), AfyaKitRoutes('afya'));
      bool current = true;
      final future = service.pollStatusUntilTerminal(
        paymentId: 'synthetic',
        firstDelay: Duration.zero,
        isCurrent: () => current,
        onTick: (_) => ticks++,
      );
      final assertion = expectLater(future, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      current = false;
      pending.complete(
        Response(
          requestOptions: RequestOptions(),
          data: {
            'payment': {
              'paymentId': 'synthetic',
              'status': 'stk_success',
              'amount': 10,
              'currency': 'KES',
              'updatedAtIso': '2026-01-01T00:00:00Z',
              'verificationStatus': 'unverified',
            },
          },
        ),
      );
      await assertion;
      expect(requests, 1);
      expect(ticks, 0);
    },
  );
}
