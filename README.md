<!-- wisent-banner:start -->
<p align="center">
  <img src="assets/readme-banner.webp" alt="wisent-desktop-update by Wisent" width="100%">
</p>
<!-- wisent-banner:end -->

<!-- wisent-readme-signals:start -->
[![Source](https://img.shields.io/badge/GitHub-Source-181717?logo=github)](https://github.com/wisent-ai/wisent-desktop-update) [![Issues](https://img.shields.io/badge/GitHub-Issues-181717?logo=github)](https://github.com/wisent-ai/wisent-desktop-update/issues) [![Wisent](https://img.shields.io/badge/Wisent-Website-0B0B0B)](https://wisent.com) [![Discord](https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white)](https://discord.gg/qRjpkthq54) [![LinkedIn](https://img.shields.io/badge/LinkedIn-Follow-0A66C2?logo=linkedin&logoColor=white)](https://www.linkedin.com/company/wisent-ai/) [![X](https://img.shields.io/badge/X-Follow-000000?logo=x&logoColor=white)](https://x.com/wisentai) [![Enterprise](https://img.shields.io/badge/Enterprise-Book%20a%20call-0B0B0B?logo=calendly)](https://calendly.com/lbartoszcze)
<!-- wisent-readme-signals:end -->

# wisent-desktop-update

Ship a Mac App Update Without Shipping a Release Process.

Every native application needs the same updater: a Sparkle `Check for Updates…`
command that reads a signed appcast and verifies each archive against the app's
`SUPublicEDKey`. Wisent Desktop Update is that updater once, shared by every
Wisent macOS app. Building, signing, notarizing and publishing a release is
Stado's: `stado build submit <app>` publishes it and Stado serves the feed at
`/api/release/appcast?product=<app>`. Both source bundles and release pipelines
resolve its deployment origin through
`stado web origin url /api/release/appcast --query product=<app>`.
The release manifest describes the product and bundle, not a deployment host.
`WISENT_UPDATE_FEED_URL` selects an explicit staging feed instead. Empty or
non-HTTPS answers and registry failures stop the bundle build; there is no
fallback to a checked-in address. An unavailable registry must be repaired at
the declared Stado storage service, not replaced with a guessed public URL.
Checked-in `App/Info.plist` templates keep `SUFeedURL` empty. The builder
writes the resolved HTTPS address into the bundle copy, never back into the
source template, so a build cannot publish its deployment address in Git.

## Building from source

The package links Sparkle's checksummed binary archive directly. Its URL and
checksum come from the same upstream release the former Git wrapper selected;
the framework and public updater API have not changed.

Use `stado product swift --package-path . build` for an owner-local build.
The shared builder resolves source dependencies from canonical `main` checkouts
and refuses missing or ambiguous sources instead of creating another checkout.
Its command results and source records remain under `.wisent-output/native/`.
Preparing a consumer app is not signing it: the app's normal signing and
installation steps must still verify the complete bundle before replacement.

## Real consumer feed verification

Run `node tests/feed/bundle.mjs --app-root <consumer-checkout>` from this
repository. The runner uses the consumer's declared bundle command, disables
installation and restart, reads the live Stado feed, and checks the built
bundle's `SUFeedURL`. It also requires the real builder to refuse an HTTP
override, then restores a valid source bundle through the same build command.
It uses the sole consumer checkout and leaves application installations alone.

Reports, exact source revisions, command exit statuses, logs and the fetched
appcast remain under `.build/real-tests/feed/`. A registry, signing, dependency
or feed failure is blocked qualification, not a passing update test. This test
checks bundle feed selection and reachability; it does not claim a completed
Sparkle installation or a graphical update journey.
