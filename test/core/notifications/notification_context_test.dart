import 'package:flutter_test/flutter_test.dart';
import 'package:afyakit/core/notifications/notification_context.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/auth/auth_user/extensions/user_status_x.dart';

void main() {
  const user = AuthUser(
    uid: 'one',
    tenantId: 'afya',
    status: UserStatus.active,
    appMembershipsByApp: {
      'dawapap': AppMembership(status: AppMembershipStatus.active),
    },
  );
  const data = {
    'tenantId': 'afya',
    'appId': 'dawapap',
    'recipientUid': 'one',
    'type': 'chat_message',
  };
  test('exact active context permits generic chat and activity notices', () {
    expect(
      matchesNotificationContext(
        data,
        user,
        'dawapap',
        authenticatedUid: 'one',
      ),
      true,
    );
    expect(
      matchesNotificationContext(
        {...data, 'type': 'activity'},
        user,
        'dawapap',
        authenticatedUid: 'one',
      ),
      true,
    );
  });
  test(
    'missing context, different account/app/tenant, logout and revoked membership deny',
    () {
      for (final key in data.keys) {
        expect(
          matchesNotificationContext(
            {...data}..remove(key),
            user,
            'dawapap',
            authenticatedUid: 'one',
          ),
          false,
        );
        expect(
          matchesNotificationContext(
            {...data, key: 'other'},
            user,
            'dawapap',
            authenticatedUid: 'one',
          ),
          false,
        );
      }
      expect(
        matchesNotificationContext(
          data,
          user,
          'other',
          authenticatedUid: 'one',
        ),
        false,
      );
      expect(
        matchesNotificationContext(
          data,
          user,
          'dawapap',
          authenticatedUid: null,
        ),
        false,
      );
      expect(
        matchesNotificationContext(
          data,
          user,
          'dawapap',
          authenticatedUid: 'new-user',
        ),
        false,
      );
      expect(
        matchesNotificationContext(
          data,
          user.copyWith(status: UserStatus.disabled),
          'dawapap',
          authenticatedUid: 'one',
        ),
        false,
      );
      expect(
        matchesNotificationContext(
          data,
          user.copyWith(appMembershipsByApp: {}),
          'dawapap',
          authenticatedUid: 'one',
        ),
        false,
      );
    },
  );
}
