import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart';
import 'package:humhub/models/hum_hub.dart';
import 'package:humhub/models/manifest.dart';
import 'package:humhub/pages/web_view.dart';
import 'package:humhub/util/providers.dart';
import 'package:http/http.dart' as http;
import 'package:loggy/loggy.dart';
import 'package:rive/rive.dart';
import '../api_provider.dart';
import '../connectivity_plugin.dart';
import '../form_helper.dart';

class VisibilityNotifier extends StateNotifier<bool> {
  VisibilityNotifier() : super(false);

  void toggleVisibility(bool isVisible) {
    state = isVisible;
  }
}

final textFieldVisibilityProvider = StateNotifierProvider<VisibilityNotifier, bool>(
  (ref) => VisibilityNotifier(),
);

final languageSwitcherVisibilityProvider = StateNotifierProvider<VisibilityNotifier, bool>(
  (ref) => VisibilityNotifier(),
);

final visibilityProvider = StateNotifierProvider<VisibilityNotifier, bool>(
  (ref) => VisibilityNotifier(),
);

final searchBarVisibilityNotifier = StateNotifierProvider<VisibilityNotifier, bool>(
  (ref) => VisibilityNotifier(),
);

class OpenerController {
  late AsyncValue<Manifest>? asyncData;
  bool doesViewExist = false;
  TextEditingController urlTextController = TextEditingController();
  late String? postcodeErrorMessage;
  final String formUrlKey = "redirect_url";
  final String error404 = "404";
  final String noConnection = "no_connection";
  final WidgetRef ref;
  late RiveAnimationController _animationForwardController;
  late SimpleAnimation _animationForward;
  late RiveAnimationController _animationReverseController;
  late SimpleAnimation _animationReverse;

  RiveAnimationController get animationForwardController => _animationForwardController;
  SimpleAnimation get animationForward => _animationForward;
  RiveAnimationController get animationReverseController => _animationReverseController;
  SimpleAnimation get animationReverse => _animationReverse;

  final FormHelper helper = FormHelper();

  OpenerController({required this.ref});

  /// Finds the `manifest.json` file associated with the given URL. If the URL does not
  /// directly point to the `manifest.json` file, it traverses up the directory structure
  /// to locate it. If not found, it assumes a default path format. This method makes
  /// asynchronous requests to fetch the manifest data.
  ///
  /// @param url The URL from which to start searching for the `manifest.json` file.
  /// @return A Future that completes with no result once the `manifest.json` file is found
  /// or the default path is assumed, or if an error occurs during the search process.
  /// Additionally, it may trigger a check for the HumHub module view based on the start URL
  /// obtained from the manifest data.
  ///
  /// @throws Exception if an error occurs during the search process.
  Future<String?> findManifest(String url) async {
    List<String> possibleUrls = generatePossibleManifestsUrls(url);
    String? manifestUrl;
    for (var url in possibleUrls) {
      asyncData = await APIProvider.of(ref).request(Manifest.get(url));
      manifestUrl = Manifest.getUriWithoutExtension(url);
      if (!asyncData!.hasError) break;
    }
    return manifestUrl;
  }

  checkHumHubModuleView(String url) async {
    Response? response;
    response = await http.Client().get(Uri.parse(url)).catchError((err) {
      return Response("Found manifest but not humhub.modules.ui.view tag", 404);
    });

    doesViewExist = response.statusCode == 200 && response.body.contains('humhub.modules.ui.view');
  }

  initHumHub() async {
    // Validate the URL format and if !value.isEmpty
    if (!helper.validate()) return;
    helper.save();

    var hasConnection = await ConnectivityPlugin.hasConnectivity;
    if (!hasConnection) {
      String value = urlTextController.text;
      urlTextController.text = noConnection;
      helper.validate();
      urlTextController.text = value;
      asyncData = null;
      return;
    }
    // Get the manifest.json for given url.
    String? manifestUrl = await findManifest(helper.model[formUrlKey]!);
    if (asyncData!.hasValue && manifestUrl != null) {
      await checkHumHubModuleView(asyncData!.value!.startUrl);
    }
    // If manifest.json does not exist the url is incorrect.
    // This is a temp. fix the validator expect sync function this is established workaround.
    // In the future we could define our own TextFormField that would also validate the API responses.
    // But it this is not acceptable I can suggest simple popup or tempPopup.
    if (asyncData!.hasError || !doesViewExist || manifestUrl == null) {
      logError("Open URL error: $asyncData");
      String value = urlTextController.text;
      urlTextController.text = error404;
      helper.validate();
      urlTextController.text = value;
    } else {
      Manifest manifest = asyncData!.value!;
      // Set the manifestStateProvider with the manifest value so that it's globally accessible
      // Generate hash and save it to store
      String lastUrl = "";
      lastUrl = await ref.read(humHubProvider).getLastUrl();
      String currentUrl = urlTextController.text;
      String hash = HumHub.generateHash(32);
      if (lastUrl == currentUrl) hash = ref.read(humHubProvider).randomHash ?? hash;
      await ref.read(humHubProvider).setInstance(HumHub(
          manifest: manifest, randomHash: hash, manifestUrl: manifestUrl, history: ref.read(humHubProvider).history));
    }
  }

  bool get allOk => !(asyncData == null || asyncData!.hasError || !doesViewExist);
  // TODO: Add localization
  String? validateUrl(String? value) {
    if (value == error404) return 'Your HumHub installation does not exist';
    if (value == noConnection) return 'Please check your internet connection.';
    if (value == null || value.isEmpty) {
      return 'Specify you HumHub location';
    }
    return null;
  }

  static List<String> generatePossibleManifestsUrls(String url) {
    List<String> urls = [];
    Uri uri = assumeUrl(url);

    for (var i = uri.pathSegments.length; i >= 0; i--) {
      String urlIn = "${uri.origin}/${uri.pathSegments.getRange(0, i).join('/')}";
      urls.add(Manifest.defineUrl(i != 0 ? urlIn : uri.origin));
    }
    for (var i = uri.pathSegments.length; i >= 0; i--) {
      String urlIn = "${uri.origin}/${uri.pathSegments.getRange(0, i).join('/')}";
      urls.add(Manifest.defineUrl(i != 0 ? urlIn : uri.origin, isUriPretty: false));
    }
    return urls;
  }

  static Uri assumeUrl(String url) {
    if (url.startsWith("https://") || url.startsWith("http://")) return Uri.parse(url);
    return Uri.parse("https://$url");
  }

  setForwardAnimation(SimpleAnimation animation) {
    _animationForward = animation;
    _animationForwardController = _animationForward;
  }

  setReverseAnimation(SimpleAnimation animation) {
    _animationReverse = animation;
    _animationReverseController = _animationReverse;
  }

  void animationNavigationWrapper({required Future<void> Function() navigate}) {
    FocusManager.instance.primaryFocus?.unfocus();
    _animationForwardController.isActive = true;
    ref.read(visibilityProvider.notifier).toggleVisibility(false);
    ref.read(textFieldVisibilityProvider.notifier).toggleVisibility(false);
    ref.read(languageSwitcherVisibilityProvider.notifier).toggleVisibility(false);

    Future.delayed(const Duration(milliseconds: 700)).then((_) {
      navigate().then((value) {
        _animationForwardController.isActive = true;
        _animationForward.reset();
        ref.read(visibilityProvider.notifier).toggleVisibility(true);

        Future.delayed(const Duration(milliseconds: 700), () {
          ref.read(textFieldVisibilityProvider.notifier).toggleVisibility(true);
          ref.read(languageSwitcherVisibilityProvider.notifier).toggleVisibility(true);
        });

        _animationReverseController.isActive = true;
      });

      _animationReverseController.isActive = true;
      _animationReverse.reset();
    });
  }

  Future<void> connect() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await initHumHub();
    if (allOk) {
      ref.read(humHubProvider).getInstance().then((instance) {
        FocusManager.instance.primaryFocus?.unfocus();
        animationNavigationWrapper(
          navigate: () => Navigator.pushNamed(ref.context, WebView.path, arguments: instance.manifest),
        );
      });
    }
  }

  dispose() {
    urlTextController.dispose();
    _animationForwardController.dispose();
    _animationReverseController.dispose();
    _animationForward.dispose();
    _animationReverse.dispose();
  }
}
