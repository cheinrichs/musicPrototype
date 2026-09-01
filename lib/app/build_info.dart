import 'package:package_info_plus/package_info_plus.dart';

/// The commit this binary was built from. Baked in at compile time via
/// --dart-define=COMMIT_SHA=... (see .github/workflows/deploy.yml and the
/// Makefile's run-ios/run-ios-dev/build-ios targets) — package_info_plus
/// can read the real installed version/build number back out of the
/// binary itself, but the commit it was built from isn't recorded
/// anywhere else, so it has to be passed in this way instead.
const String kCommitSha = String.fromEnvironment(
  'COMMIT_SHA',
  defaultValue: 'unknown',
);

/// Version/build/commit identifying exactly which binary produced a
/// report — see [RoundReport] (round_report.dart), the only current
/// consumer.
class BuildInfo {
  final String appVersion;
  final String buildNumber;
  final String commitSha;

  const BuildInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.commitSha,
  });

  Map<String, dynamic> toJson() => {
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'commitSha': commitSha,
  };

  /// Reads the version/build number actually embedded in this installed
  /// binary (so it reflects whatever CI stamped on, e.g.
  /// `--build-number=` the GitHub Actions run number — see deploy.yml)
  /// plus the commit SHA baked in at compile time.
  static Future<BuildInfo> current() async {
    final info = await PackageInfo.fromPlatform();
    return BuildInfo(
      appVersion: info.version,
      buildNumber: info.buildNumber,
      commitSha: kCommitSha,
    );
  }
}
