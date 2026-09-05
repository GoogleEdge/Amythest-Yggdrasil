# Amethyst Yggdrasil · Material 3 inspired UI

The original Amethyst-iOS source is pinned in `amethyst-original/`; the
external-login and interface changes are in `overlay/Amethyst-iOS/`.

```sh
git clone --recurse-submodules https://github.com/GoogleEdge/Amythest-Yggdrasil.git
```

## Interface

This version implements a **Material Design 3 inspired UIKit interface**.
It is not a Flutter/Dart migration and does not embed Flutter Engine.
It preserves the Objective-C, Java/JNI, JIT, resource-download, Microsoft,
and external Yggdrasil login implementations.

Changes include amethyst light/dark tonal colors, launcher header,
rounded navigation/account/profile/settings surfaces, account chip,
version field and filled launch button. System authentication UI, document
pickers, the Minecraft game surface and control editor keep their own UI.

Theme code: `Natives/AmethystMD3Theme.h` and `.m` in the overlay.

## Build and distribution

The GitHub Actions workflow uses the Apple iPhoneOS SDK and actual
Objective-C/C/Java compilation. No dry-run, smoke-test, local test, or
simulation is part of the acceptance workflow. Compilation does not
establish on-device layout or gameplay correctness.

Download the `amethyst-material3-unsigned-ios-ipa` Actions artifact:

- `Amethyst-Material3-unsigned.ipa`
- `Amethyst-Material3-unsigned.ipa.sha256`
- `entitlements.sideload.xml`

The packaging stage removes upstream ad-hoc/bundled signatures and
provisioning data from the fresh payload before creating the IPA.
Sign it using your own iOS signing workflow. The separate entitlement
file retains the upstream requirements; your signing method must support
the permissions needed for this launcher and its JIT workflow.

The external Yggdrasil login flow is unchanged. Passwords are not stored;
the access token remains connected to Minecraft's launch credentials.
