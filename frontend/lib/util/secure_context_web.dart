// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Only compiled in on web (see secure_context.dart's conditional export),
// matching open_url_web.dart's use of dart:html.
import 'dart:html' as html;

/// Browsers expose `navigator.mediaDevices` only on a secure context (HTTPS or
/// localhost), so the web build served over plain LAN HTTP -- the default
/// standalone Docker deployment -- has no camera API at all and
/// `mobile_scanner` reports `unsupported`. That is a property of the origin,
/// not of the device, and saying "not supported on this device" sends the user
/// away from the one setting that would fix it (#329).
bool get cameraBlockedByInsecureOrigin =>
    html.window.isSecureContext == false && html.window.navigator.mediaDevices == null;
