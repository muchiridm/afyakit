import 'dart:async';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/profiles_service.dart';
import 'package:afyakit/features/records/health_profiles/profiles_controller.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_self_app_access_section.dart';

Map<String, Object?> options([List<String> ids = const ['one']]) => {
  'profile_id': 'p',
  'app_ids': ids,
  'revision': '1:2',
  'apps': [
    {'app_id': 'one', 'enrolled': ids.contains('one')},
  ],
  'consent': {'version': 'v1', 'notice': 'Synthetic notice'},
};

class FakeProfiles extends ProfilesService {
  FakeProfiles()
    : super(
        api: AfyaKitClient(Dio()),
        routes: AfyaKitRoutes('demo'),
        isCurrent: () => true,
      );
  final requests = <Completer<List<Profile>>>[];
  bool removed = false;
  bool denyRefresh = false;
  Completer<ProfileSharingOptions>? pendingOptions;
  @override
  Future<List<Profile>> list({
    String? search,
    String? accountNumber,
    ProfileContactRelationship? relationship,
    bool? isActive,
    int page = 1,
    int perPage = 50,
  }) {
    final c = Completer<List<Profile>>();
    requests.add(c);
    return c.future;
  }

  @override
  Future<ProfileSharingOptions> eligibleSelfApps(String profileId) async {
    if (removed && denyRefresh) throw StateError('Access changed after commit');
    return pendingOptions != null
      ? await pendingOptions!.future
      : ProfileSharingOptions(
          profileId: profileId,
          appIds: removed ? [] : ['one'],
          revision: '1:2',
          apps: [EligibleProfileApp(appId: 'one', enrolled: !removed)],
          consentVersion: 'v1',
          consentNotice: 'Synthetic',
        );
  }
  @override
  Future<void> revokeOwnProfileApp({
    required String profileId,
    required String targetAppId,
  }) async {
    removed = true;

  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real service sends consent revision and never expects a clinical profile response',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.data['revision'], '1:2');
            expect(request.data['consent_accepted'], true);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'ok': true, 'profile_id': 'p'},
              ),
            );
          },
        ),
      );
      final service = ProfilesService(
        api: AfyaKitClient(dio),
        routes: AfyaKitRoutes('demo'),
        isCurrent: () => true,
      );
      await service.shareOwnProfile(
        profileId: 'p',
        destinationAppId: 'one',
        consentVersion: 'v1',
        revision: '1:2',
      );


    },
  );
  test(
    'real service rejects delayed responses after authorization context changes',
    () async {
      var current = true;
      final pending = Completer<void>();
      final requested = Completer<void>();
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) async {
            requested.complete();
            await pending.future;
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'ok': true, 'profile_id': 'p'},
              ),
            );
          },
        ),
      );
      final service = ProfilesService(
        api: AfyaKitClient(dio),
        routes: AfyaKitRoutes('demo'),
        isCurrent: () => current,
      );
      final result = service.eligibleSelfApps('p');
      final check = expectLater(result, throwsStateError);
      await requested.future;
      current = false;
      pending.complete();
      await check;
    },
  );
  test(
    'controller rejects superseded loads and clears records on access denial',
    () async {
      final service = FakeProfiles();
      final c = ProfilesController(() => service);
      final first = c.load();
      final second = c.load();
      service.requests[1].complete([
        Profile.fromJson({
          'profile_id': 'visible',
          'full_name': 'Synthetic',
          'is_active': true,
          'app_ids': ['one'],
        }),
      ]);
      await second;
      service.requests[0].completeError(StateError('stale'));
      await first;
      expect(c.state.error, isNull);
      expect(c.state.items.single.profileId, 'visible');
      final third = c.load();
      service.requests[2].completeError(StateError('denied'));
      await third;
      expect(c.state.items, isEmpty);
      expect(c.state.linkRequests, isEmpty);
      final fourth = c.load();
      c.dispose();
      service.requests[3].complete([]);
      await fourth;
    },
  );
  testWidgets(
    'sharing options from a previous profile/context cannot replace current options',
    (tester) async {
      final oldService = FakeProfiles()
        ..pendingOptions = Completer<ProfileSharingOptions>();
      final oldController = ProfilesController(() => oldService);
      final currentController = ProfilesController(() => FakeProfiles());
      Widget screen(String id, ProfilesController c) => MaterialApp(
        home: Scaffold(
          body: ProfileSelfAppAccessSection(
            profileId: id,
            currentAppId: 'one',
            controller: c,
            busy: false,
          ),
        ),
      );
      await tester.pumpWidget(screen('old', oldController));
      await tester.pump();
      await tester.pumpWidget(screen('new', currentController));
      await tester.pumpAndSettle();
      oldService.pendingOptions!.complete(
        const ProfileSharingOptions(
          profileId: 'old',
          appIds: ['STALE_APP'],
          revision: 'old',
          apps: [],
          consentVersion: 'v',
          consentNotice: 'old',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('STALE_APP'), findsNothing);
      expect(find.text('one'), findsOneWidget);
      oldController.dispose();
      currentController.dispose();
    },
  );
  testWidgets(
    'owner can remove current and last app through metadata-only management',
    (tester) async {
      final service = FakeProfiles();
      final c = ProfilesController(() => service);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileSelfAppAccessSection(
              profileId: 'p',
              currentAppId: 'one',
              controller: c,
              busy: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove access'));
      await tester.pumpAndSettle();
      expect(service.removed, true);
      expect(find.text('Add to app'), findsOneWidget);
      c.dispose();
    },
  );
  testWidgets('committed withdrawal stays successful when options refresh fails', (tester) async {
    final service = FakeProfiles()..denyRefresh = true;
    final controller = ProfilesController(() => service);
    var changed = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProfileSelfAppAccessSection(
      profileId: 'p', currentAppId: 'one', controller: controller, busy: false,
      onChanged: () => changed = true,
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove access'));
    await tester.pumpAndSettle();
    expect(service.removed, true);
    expect(changed, true);
    expect(find.text('Removed one access'), findsOneWidget);
    expect(find.text('Unable to remove application access. Please try again.'), findsNothing);
    expect(find.text('Could not load application access. Try again.'), findsOneWidget);
    controller.dispose();
  });

}
