import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:humhub/flavored/models/humhub.f.dart';
import 'package:humhub/flavored/util/intent_plugin.f.dart';
import 'package:humhub/flavored/util/router.f.dart';
import 'package:humhub/util/loading_provider.dart';
import 'package:humhub/util/notifications/plugin.dart';
import 'package:humhub/util/override_locale.dart';
import 'package:humhub/util/push/push_plugin.dart';
import 'package:humhub/util/storage_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

class FlavoredApp extends ConsumerStatefulWidget {
  const FlavoredApp({super.key});

  @override
  FlavoredAppState createState() => FlavoredAppState();
}

class FlavoredAppState extends ConsumerState<FlavoredApp> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SecureStorageService.clearSecureStorageOnReinstall();
    return LoadingProvider(
      child: IntentPluginF(
        child: NotificationPlugin(
          child: PushPlugin(
            child: OverrideLocale(
              builder: (overrideLocale) => Builder(
                builder: (context) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  initialRoute: RouterF.initRoute,
                  routes: RouterF.routes,
                  localizationsDelegates: AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  navigatorKey: navigatorKeyF,
                  builder: (context, child) => child!,
                  theme: ThemeData(
                    fontFamily: 'OpenSans',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final humHubFProvider = FutureProvider<HumHubF>((ref) {
  return HumHubF.initialize();
});
