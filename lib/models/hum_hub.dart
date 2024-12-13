import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:humhub/app_flavored.dart';
import 'package:humhub/app_opener.dart';
import 'package:humhub/models/global_package_info.dart';
import 'package:humhub/models/manifest.dart';
import 'package:humhub/util/log.dart';
import 'package:humhub/util/openers/universal_opener_controller.dart';
import 'package:humhub/util/permission_handler.dart';
import 'package:humhub/util/storage_service.dart';
import 'package:loggy/loggy.dart';
import 'package:permission_handler/permission_handler.dart';

enum RedirectAction { opener, webView }

enum OpenerState {
  shown(true),
  hidden(false);

  final bool value;

  const OpenerState(this.value);

  String get headerValue => value ? '1' : '0';

  @override
  String toString() {
    return value ? "shown" : "hidden";
  }
}

class HumHub {
  Manifest? manifest;
  String? manifestUrl;
  OpenerState openerState;
  String? randomHash;
  String? appVersion;
  String? pushToken;
  final bool isIos = Platform.isIOS || Platform.isMacOS;
  final bool isAndroid = Platform.isAndroid;
  List<Manifest> _history;

  List<Manifest> get history => _history;

  HumHub({
    this.manifest,
    this.manifestUrl,
    this.openerState = OpenerState.shown,
    this.randomHash,
    this.appVersion,
    this.pushToken,
    List<Manifest>? history,
  }) : history = history ?? [];

  Map<String, dynamic> toJson() => {
        'manifest': manifest?.toJson(),
        'manifestUri': manifestUrl,
        'openerState': openerState.value,
        'randomHash': randomHash,
        'appVersion': appVersion,
        'pushToken': pushToken,
        'history': _history
            .map((manifest) => manifest.toJson())
            .toList(), // Serialize history
      };

  factory HumHub.fromJson(Map<String, dynamic> json) {
    return HumHub(
      manifest:
          json['manifest'] != null ? Manifest.fromJson(json['manifest']) : null,
      manifestUrl: json['manifestUri'],
      openerState: (json['openerState'] as bool?) ?? true ? OpenerState.shown : OpenerState.hidden,
      randomHash: json['randomHash'],
      appVersion: json['appVersion'],
      pushToken: json['pushToken'],
      history: json['history'] != null
          ? List<Manifest>.from(
              json['history'].map((json) => Manifest.fromJson(json)))
          : [], // Deserialize history
    );
  }

  /// Adds a new [Manifest] to the history.
  ///
  /// This method checks if a [Manifest] with the same [startUrl] as the
  /// provided [newManifest] already exists in the history. If it does,
  /// the existing manifest will be updated with the new one. If not,
  /// the new manifest will be added to the history list.
  ///
  /// [newManifest] The [Manifest] object to be added to the history.
  /// If a manifest with the same [startUrl] exists, it will be updated.
  ///
  /// Note: The [Manifest] class should have a valid `startUrl`
  /// property for this method to work correctly. The history list
  /// will maintain unique entries based on the `startUrl`.
  /// !!! This method should only be called inside a [HumHubNotifier] because it also needs to update secure storage.
  void addToHistory(Manifest newManifest) {
    final existingManifestIndex =
        _history.indexWhere((item) => item.startUrl == newManifest.startUrl);

    if (existingManifestIndex >= 0) {
      history[existingManifestIndex] = newManifest;
    } else {
      history.add(newManifest);
    }
  }

  /// Removes a [Manifest] from the history based on its [startUrl].
  ///
  /// This method searches for a [Manifest] with the specified [startUrl]
  /// in the history. If found, it removes the manifest from the list.
  ///
  /// [startUrl] The start URL of the [Manifest] to be removed from the history.
  ///
  /// Returns true if the manifest was successfully removed,
  /// or false if no matching manifest was found.
  /// Note: The history will not maintain any references to the
  /// removed manifest after this operation.
  /// !!! This method should only be called inside a [HumHubNotifier] because it also needs to update secure storage.
  bool removeFromHistory(Manifest manifest) {
    final existingManifestIndex =
        _history.indexWhere((item) => item == manifest);

    if (existingManifestIndex >= 0) {
      history.removeAt(existingManifestIndex); // Remove the manifest
      return true;
    } else {
      return false;
    }
  }

  Future<RedirectAction> action(ref) async {
    if (OpenerState.shown.value) {
      return RedirectAction.opener;
    } else {
      if (manifest != null) {
        UniversalOpenerController openerController =
            UniversalOpenerController(url: manifest!.baseUrl);
        String? manifestUrl =
            await openerController.findManifest(manifest!.baseUrl);
        if (manifestUrl == null) {
          return RedirectAction.opener;
        } else {
          return RedirectAction.webView;
        }
      }
      return RedirectAction.webView;
    }
  }

  static String generateHash(int length) {
    final random = Random.secure();
    const characters = '0123456789abcdef';
    return List.generate(
        length, (_) => characters[random.nextInt(characters.length)]).join();
  }

  Map<String, String> get customHeaders => {
        'x-humhub-app-token': randomHash!,
        'x-humhub-app': appVersion ?? '1.0.0',
        'x-humhub-app-ostate': isHideOpener ? '1' : '0',
        'x-humhub-app-is-ios': isIos ? '1' : '0',
        'x-humhub-app-is-android': isAndroid ? '1' : '0'
        'x-humhub-app-opener-state': openerState.headerValue,
        'x-humhub-app-is-multi-instance': '1',
      };

  static Future<Widget> init() async {
    Loggy.initLoggy(
      logPrinter: const GlobalLog(),
    );
    WidgetsFlutterBinding.ensureInitialized();
    await SecureStorageService.clearSecureStorageOnReinstall();
    await GlobalPackageInfo.init();
    await PermissionHandler.requestPermissions(
      [
        Permission.notification,
        Permission.camera,
        Permission.microphone,
        Permission.storage,
        Permission.photos
      ],
    );
    switch (GlobalPackageInfo.info.packageName) {
      case 'com.humhub.app':
        return const OpenerApp();
      default:
        await dotenv.load(fileName: "assets/.env");
        return const FlavoredApp();
    }
  }
}
