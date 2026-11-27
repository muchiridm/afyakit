import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/core/notifications/notification_lifecycle.dart';
import 'package:afyakit/core/notifications/notification_service.dart';

const user = AuthUser(
  uid: 'member',
  tenantId: 'afya',
  status: UserStatus.active,
  appMembershipsByApp: {
    'dawapap': AppMembership(status: AppMembershipStatus.active),
  },
);

class FakeService extends NotificationService {
  FakeService() : super(AfyaKitClient(Dio()), AfyaKitRoutes('afya'));
  late NotificationLifecycle lifecycle;
  final cancelled = <String>[];
  final revoked = <String>[];
  final previous = <Map<String, dynamic>?>[];
  final ids = <String>[];
  Completer<void>? confirming;
  Completer<void>? revoking;
  Completer<bool>? validation;
  bool sendProof = true;
  Map<String, dynamic>? registration;
  @override
  Future<Map<String, dynamic>> begin(
    String id,
    String token,
    Map<String, dynamic>? old,
  ) async {
    ids.add(id);
    previous.add(old);
    if (sendProof) {
      lifecycle.receiveProof({
        'type': 'notification_possession',
        'challengeId': id,
        'proof': 'synthetic-proof',
      });
    }
    return {'challengeId': id};
  }

  @override
  Future<Map<String, dynamic>> confirm(String id, String proof) async {
    if (confirming != null) await confirming!.future;
    registration = {
      'registrationId': id,
      'generation': 'generation-$id',
      'expiresAt': DateTime.now()
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch,
    };
    return registration!;
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
  }

  @override
  Future<void> revoke(Map<String, dynamic> registration) async {
    revoked.add(registration['registrationId']);
    if (revoking != null) await revoking!.future;
  }

  @override
  Future<bool> validate(Map<String, dynamic> registration) async =>
      validation == null ? true : await validation!.future;
}

Future<void> settle() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Map<String, dynamic> payload(FakeService service) => {
  'type': 'chat_message',
  'tenantId': 'afya',
  'appId': 'dawapap',
  'recipientUid': 'member',
  ...service.registration!,
};
void main() {
  test(
    'early challenge delivery, refresh replacement and unsolicited proofs',
    () async {
      final service = FakeService();
      var token = 'first';
      final lifecycle = NotificationLifecycle.testing(
        currentUid: () => 'member',
        createService: (_, _, _) async => service,
        obtainToken: () async => token,
        tabsAgree: (_) async => true,
      );
      service.lifecycle = lifecycle;
      lifecycle.receiveProof({
        'type': 'notification_possession',
        'challengeId': 'unsolicited',
        'proof': 'wrong',
      });
      lifecycle.attach(Object(), user, 'dawapap');
      await settle();
      expect(await lifecycle.validateDisplay(payload(service)), true);
      token = 'second';
      await lifecycle.refresh();
      expect(service.previous.last?['registrationId'], service.ids.first);
      expect(service.ids.toSet().length, 2);
      await lifecycle.clear();
      expect(await lifecycle.validateDisplay(payload(service)), false);
      expect(service.revoked.length, 1);
    },
  );
  test(
    'logout during confirmation cancels the exact late activation',
    () async {
      final service = FakeService()..confirming = Completer<void>();
      final lifecycle = NotificationLifecycle.testing(
        currentUid: () => 'member',
        createService: (_, _, _) async => service,
        obtainToken: () async => 'token',
        tabsAgree: (_) async => true,
      );
      service.lifecycle = lifecycle;
      lifecycle.attach(Object(), user, 'dawapap');
      await settle();
      await lifecycle.clear();
      service.confirming!.complete();
      await settle();
      expect(lifecycle.context, null);
      expect(service.cancelled, contains(service.ids.single));
      expect(await lifecycle.validateDisplay(payload(service)), false);
    },
  );
  test(
    'membership loss and conflicting tabs revoke registration and suppress handling',
    () async {
      final service = FakeService();
      var agreement = true;
      final lifecycle = NotificationLifecycle.testing(
        currentUid: () => 'member',
        createService: (_, _, _) async => service,
        obtainToken: () async => 'token',
        tabsAgree: (_) async => agreement,
      );
      service.lifecycle = lifecycle;
      lifecycle.attach(Object(), user, 'dawapap');
      await settle();
      agreement = false;
      await lifecycle.refresh();
      expect(service.revoked.length, 1);
      expect(await lifecycle.validateDisplay(payload(service)), false);
      lifecycle.attach(
        Object(),
        user.copyWith(appMembershipsByApp: {}),
        'dawapap',
      );
      expect(lifecycle.context, null);
    },
  );
  test(
    'local context clears synchronously while offline revocation is pending',
    () async {
      final service = FakeService()..revoking = Completer<void>();
      final lifecycle = NotificationLifecycle.testing(
        currentUid: () => 'member',
        createService: (_, _, _) async => service,
        obtainToken: () async => 'token',
        tabsAgree: (_) async => true,
      );
      service.lifecycle = lifecycle;
      lifecycle.attach(Object(), user, 'dawapap');
      await settle();
      final clearing = lifecycle.clear();
      expect(lifecycle.context, null);
      expect(await lifecycle.validateDisplay(payload(service)), false);
      service.revoking!.complete();
      await clearing;
    },
  );
  test(
    'late backend display approval cannot survive an account/context change',
    () async {
      final service = FakeService()..validation = Completer<bool>();
      var uid = 'member';
      final lifecycle = NotificationLifecycle.testing(
        currentUid: () => uid,
        createService: (_, _, _) async => service,
        obtainToken: () async => 'token',
        tabsAgree: (_) async => true,
      );
      service.lifecycle = lifecycle;
      lifecycle.attach(Object(), user, 'dawapap');
      await settle();
      final allowed = lifecycle.validateDisplay(payload(service));
      uid = 'other';
      await lifecycle.clear();
      service.validation!.complete(true);
      expect(await allowed, false);
    },
  );
}
