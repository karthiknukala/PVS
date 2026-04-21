# GitHub Actions Build And macOS Packaging Notes

This directory contains the GitHub Actions workflows used to build PVS bundles for Apple Silicon, Apple x86, Linux ARM, and Linux x86.

This README focuses on the current packaging, notarization, and release flow, using Apple Silicon as the concrete example. The Apple x86 and Linux workflows mirror the same structure.

## Current Apple Silicon Flow

The Apple Silicon workflow is defined in [.github/workflows/apple-silicon-build.yml](./workflows/apple-silicon-build.yml).

It has two jobs:

1. `build-macos-arm64`
   This job always runs. It builds the standalone Apple Silicon bundle, smoke-tests it, and uploads:
   - `pvs-apple-silicon-tgz`
   - `pvs-apple-silicon-custom-sbcl`
   - `pvs-apple-silicon-bundle`

2. `package-macos-arm64`
   This job runs automatically whenever all required signing and notarization secrets are present. It downloads the standalone tarball from the first job, rebuilds a macOS installer package from it, signs the package, notarizes it, staples the notarization ticket, and uploads:
   - `pvs-apple-silicon-pkg`

The split is intentional: the signed and notarized package path should not block the plain standalone tarball and bundle build.

Before building PVS itself, the Apple Silicon workflow installs Homebrew's native Apple Silicon `sbcl` package only as the bootstrap host, then builds a custom SBCL `2.6.3` install tree from source via [.github/scripts/install-patched-sbcl-source.sh](./scripts/install-patched-sbcl-source.sh). PVS is built against that custom SBCL, and the bundle step copies that active SBCL support tree into the release so the packaged runtime matches the source-built SBCL layout instead of shipping Homebrew's SBCL runtime directly.

That same job also uploads the source-built SBCL install tree itself as `pvs-apple-silicon-custom-sbcl`. This is useful when testing whether the custom runtime binary survives relocation to another Apple Silicon Mac before going through the full PVS bundle or pkg path.

For the SBCL runtime, the packaged bundle now carries the generated `pvs-sbclisp` and `pvs-sbclisp-bin` launchers, the saved `pvs-sbclisp.core`, and a bundled `runtime/sbcl/` tree containing the SBCL executable plus its `lib/sbcl/` support files. The launchers set `SBCL_HOME` to that bundled tree at runtime instead of assuming only a copied bare executable is sufficient.

The packaged install base is `/PVS`. That means:

- installing with `-target /` places the bundle at `/PVS/pvs-8.0`
- installing with `-target CurrentUserHomeDirectory` places it at `~/PVS/pvs-8.0`

Release publication is controlled by [.github/release-config.env](./release-config.env):

- `PVS_RELEASE_STABLE_BRANCH`
- `PVS_RELEASE_NIGHTLY_BRANCH`

Those two variables determine which branch is treated as the stable source branch and which branch is treated as the nightly source branch.

The current release policy is:

- pushes to the configured nightly branch publish or update a prerelease tagged `nightly-YYYYMMDD`
- pushes of git tags whose commits are contained in the configured stable branch publish stable releases using the pushed tag name
- for macOS, the GitHub Releases page publishes only notarized `.pkg` assets; the standalone tarballs, unpacked bundles, and custom SBCL runtime artifacts remain in GitHub Actions artifacts

This keeps both stable and nightly builds on the same GitHub Releases page while still letting the branch mapping be changed in one place during branch-based testing.

## Which Artifact To Distribute

If the goal is to minimize Gatekeeper friction for end users, distribute the notarized `.pkg` artifact. That is also the only macOS asset type now published on the GitHub Releases page.

The standalone tarball, unpacked bundle, and Apple Silicon custom-SBCL tarball are still useful build artifacts, but they are not the Gatekeeper-friendly distribution path and they now stay in GitHub Actions artifacts instead of being published on the release page. The current release flow vendors any non-system dylib dependencies discovered in the packaged runtime directory so the shipped bundle does not reach back into Homebrew on an end user's machine. The `.pkg` path then signs those Mach-O payload files, signs the installer package, and notarizes that packaged distribution.

If the goal is to isolate an Apple Silicon SBCL runtime problem before involving the rest of the PVS bundle, use `pvs-apple-silicon-custom-sbcl` first. After extracting it on another machine, run:

```bash
SBCL_HOME=<extract>/pvs-sbcl-built/lib/sbcl <extract>/pvs-sbcl-built/bin/sbcl --version
```

If that fails with the same allocation error, the remaining issue is in the shipped SBCL runtime binary itself rather than in the PVS launchers, dylib loading, or pkg relocation.

## Release Tracks

- Stable releases are intended to come from version tags whose commits are on the configured stable branch.
- Nightly releases are prereleases named with the UTC date in `YYYYMMDD` form, for example `nightly-20260420`.
- If multiple nightly builds run on the same UTC date, they update the same nightly release and replace its assets in place.

For the SBCL runtime, the packaged bundle now uses:

- `pvs-sbclisp`: a shell launcher
- `pvs-sbclisp-bin`: a shell launcher that sets `SBCL_HOME` and invokes the bundled SBCL
- `pvs-sbclisp.core`: the SBCL core image data file
- `runtime/sbcl/`: the bundled SBCL executable plus its `lib/sbcl/` support tree

This avoids Apple's strict validation failure for a monolithic self-contained SBCL executable with an appended core payload.
The `pvs-sbclisp` launcher also passes an explicit `--dynamic-space-size` to SBCL, defaulting to the build-time `SBCL_SPACE_SIZE` and overridable with `PVS_SBCL_DYNAMIC_SPACE_SIZE`, so the installed runtime does not depend on whatever default heap size the bootstrap-built SBCL binary happens to carry.
When the notarized macOS pkg path signs the bundled `runtime/sbcl/bin/sbcl` executable with Hardened Runtime, it also applies the executable-memory entitlements from [.github/macos-sbcl-entitlements.plist](./macos-sbcl-entitlements.plist): `com.apple.security.cs.allow-jit` and `com.apple.security.cs.allow-unsigned-executable-memory`. The Apple Silicon SBCL runtime can use executable-memory patterns that work in an unsigned/debug bundle but are killed by code-signing enforcement after pkg installation unless those runtime exceptions are present.

## Required Secrets

The `package-macos-arm64` job only runs if all of these secrets are non-empty:

- `MACOS_DEV_ID_APPLICATION_CERT_P12_BASE64`
- `MACOS_DEV_ID_APPLICATION_CERT_PASSWORD`
- `MACOS_DEV_ID_APPLICATION_CERT_NAME`
- `MACOS_DEV_ID_INSTALLER_CERT_P12_BASE64`
- `MACOS_DEV_ID_INSTALLER_CERT_PASSWORD`
- `MACOS_DEV_ID_INSTALLER_CERT_NAME`
- `MACOS_NOTARY_ISSUER_ID`
- `MACOS_NOTARY_KEY_ID`
- `MACOS_NOTARY_API_KEY_P8_BASE64`

If any one of these is missing, the workflow still produces the tarball and unpacked bundle, but it skips the pkg/notarization job.

## What The Certificate Files Mean

There are two separate pieces involved in the notarized package path:

- `Developer ID Application` `.p12`
  This is the exported `Developer ID Application` identity, including the private key. It is used to sign Mach-O executables and dynamic libraries inside the staged bundle before packaging.

- `Certificates.p12`
  This is the exported `Developer ID Installer` identity, including the private key. It is used to sign the installer package.

- `AuthKey_<KEY_ID>.p8`
  This is the App Store Connect API private key used by `notarytool` to authenticate with Apple's notarization service.

These files are used for different purposes:

- `Developer ID Application` `.p12` = payload signing
- `Developer ID Installer` `.p12` = package signing
- `.p8` = notarization authentication

## Developer ID Application Certificate Setup

The payload signing path uses a `Developer ID Application` certificate.

Typical flow:

1. Create a certificate signing request.
2. Request the `Developer ID Application` certificate from Apple.
3. Download the `.cer`.
4. Import the `.cer` into the login keychain.
5. Verify that the matching identity is available.
6. Export that identity as a `.p12`.

Useful commands:

```bash
security import ~/cert/developerID_application.cer -k ~/Library/Keychains/login.keychain-db
security find-identity -v -p codesigning ~/Library/Keychains/login.keychain-db | grep "Developer ID Application"
```

The identity name you put in `MACOS_DEV_ID_APPLICATION_CERT_NAME` must match the imported identity exactly.

Example:

```text
Developer ID Application: Your Name (TEAMID)
```

## Developer ID Installer Certificate Setup

The package signing path uses a `Developer ID Installer` certificate.

Typical flow:

1. Create a certificate signing request.
2. Request the `Developer ID Installer` certificate from Apple.
3. Download the `.cer`.
4. Import the `.cer` into the login keychain.
5. Verify that the matching identity is available.
6. Export that identity as a `.p12`.

Useful commands:

```bash
security import ~/cert/developerID_installer.cer -k ~/Library/Keychains/login.keychain-db
security find-identity -v -p basic ~/Library/Keychains/login.keychain-db | grep "Developer ID Installer"
```

The identity name you put in `MACOS_DEV_ID_INSTALLER_CERT_NAME` must match the imported identity exactly. To discover the exact name, use the `security find-identity` command above.

Example:

```text
Developer ID Installer: Your Name (TEAMID)
```

## Export The `.p12` Files

After the `Developer ID Application` and `Developer ID Installer` identities appear in the keychain, export each identity as a `.p12` with a password.

Once exported, base64-encode them for GitHub Secrets:

```bash
base64 < ~/cert/DeveloperIDApplication.p12 | tr -d '\n'
base64 < ~/cert/Certificates.p12 | tr -d '\n'
```

## App Store Connect API Key Setup For Notarization

The current workflow uses App Store Connect API key authentication for `notarytool`.

Important:

- Use a `Team Key`
- Do not use an `Individual Key`
- `MACOS_NOTARY_ISSUER_ID` must be the Team Key `Issuer ID` in UUID format

Apple's documentation says individual App Store Connect API keys cannot be used with `notarytool`.

Typical flow:

1. Sign in to App Store Connect.
2. Go to `Users and Access` -> `Integrations` -> `App Store Connect API`.
3. If API access is not enabled, the Account Holder must request access first.
4. Under `Team Keys`, generate a new key.
5. Download the private key file immediately.
6. Save the file somewhere secure, for example `~/cert/AuthKey_<KEY_ID>.p8`.
7. Record the `Key ID`.
8. Record the `Issuer ID`.

Base64-encode the `.p8` file for GitHub Secrets:

```bash
base64 < ~/cert/AuthKey_<KEY_ID>.p8 | tr -d '\n'
```

## Setting Secrets With `gh`

Examples below use `karthiknukala/PVS`. Replace that if you are configuring a different repository.

```bash
base64 < ~/cert/DeveloperIDApplication.p12 | tr -d '\n' | gh secret set MACOS_DEV_ID_APPLICATION_CERT_P12_BASE64 -R karthiknukala/PVS
gh secret set MACOS_DEV_ID_APPLICATION_CERT_PASSWORD -R karthiknukala/PVS
gh secret set MACOS_DEV_ID_APPLICATION_CERT_NAME -R karthiknukala/PVS --body "Developer ID Application: Your Name (TEAMID)"

base64 < ~/cert/Certificates.p12 | tr -d '\n' | gh secret set MACOS_DEV_ID_INSTALLER_CERT_P12_BASE64 -R karthiknukala/PVS
gh secret set MACOS_DEV_ID_INSTALLER_CERT_PASSWORD -R karthiknukala/PVS
gh secret set MACOS_DEV_ID_INSTALLER_CERT_NAME -R karthiknukala/PVS --body "Developer ID Installer: Your Name (TEAMID)"

gh secret set MACOS_NOTARY_ISSUER_ID -R karthiknukala/PVS
gh secret set MACOS_NOTARY_KEY_ID -R karthiknukala/PVS
base64 < ~/cert/AuthKey_<KEY_ID>.p8 | tr -d '\n' | gh secret set MACOS_NOTARY_API_KEY_P8_BASE64 -R karthiknukala/PVS
```

## What Happens Once All Secrets Are Set

Once all nine secrets are present:

1. `build-macos-arm64` builds and uploads the standalone tarball and unpacked bundle.
2. `package-macos-arm64` runs automatically.
3. The second job:
   - imports the `Developer ID Application` and `Developer ID Installer` identities into a temporary keychain
   - reconstructs the standalone bundle from the tarball artifact
   - signs Mach-O payload files in the staged bundle copy
   - builds a signed installer package
   - submits the package to Apple's notarization service
   - staples the notarization ticket
   - uploads the final `pvs-apple-silicon-pkg` artifact

## Current Authentication Choice

The workflow currently uses App Store Connect API key authentication for notarization:

- `MACOS_NOTARY_ISSUER_ID`
- `MACOS_NOTARY_KEY_ID`
- `MACOS_NOTARY_API_KEY_P8_BASE64`

It does not currently use the alternate Apple ID + app-specific password flow for `notarytool`.

## Troubleshooting

If the pkg job is skipped:

- Check that all nine secrets are present.
- `gh secret list -R karthiknukala/PVS` will show secret names, but not values.

If the `Developer ID Application` or `Developer ID Installer` identity does not appear after importing the `.cer`:

- The certificate may not be imported yet.
- The matching private key may not be in the current keychain.

If notarization fails:

- Confirm that the `MACOS_NOTARY_KEY_ID` matches the downloaded `.p8` file.
- Confirm that the `MACOS_NOTARY_ISSUER_ID` belongs to the same App Store Connect team key.
- Confirm that `MACOS_NOTARY_ISSUER_ID` is the Issuer ID UUID, not the Team ID, key name, or some other identifier.
- Confirm that the `.p8` file uploaded into `MACOS_NOTARY_API_KEY_P8_BASE64` is the original Team API key downloaded from App Store Connect.
- If the submission reaches Apple and returns `Invalid`, inspect the notarization log. Unsigned or ad hoc-signed Mach-O payload files are a common cause.

If `notarytool` exits with an error like `must be a valid UUID` for `--issuer`:

- The `MACOS_NOTARY_ISSUER_ID` secret is malformed or is not an App Store Connect Team Key Issuer ID.
- Recreate or re-copy the Issuer ID from `Users and Access` -> `Integrations` -> `App Store Connect API` -> `Team Keys`.
- Do not use an Individual API key here; Apple's current documentation says Individual keys cannot be used with `notarytool`.

## References

- [Apple Silicon workflow](./workflows/apple-silicon-build.yml)
- [macOS pkg build helper](./scripts/build-macos-pkg.sh)
- [Apple Developer: Signing your apps for Gatekeeper](https://developer.apple.com/developer-id/)
- [Apple Developer Support: Developer ID](https://developer.apple.com/support/developer-id/)
- [Apple Developer: App Store Connect API setup](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api)
- [Apple Developer: Creating API Keys for App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
- [Apple Developer: TN3147 Migrating to the latest notarization tool](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool)

## Installation

Once the pkg is built and downloaded onto a machine, run

```
installer -pkg ./pvs8.0-<build>-arm-MacOSX-sbclisp.pkg -target CurrentUserHomeDirectory
```

to have PVS installed at ~/PVS.
