# Amethyst iOS with external Yggdrasil login

This repository keeps the original Amethyst-iOS source as a pinned submodule and
stores the external Yggdrasil login changes in `overlay/`.

Clone the complete source tree with:

```sh
git clone --recurse-submodules https://github.com/GoogleEdge/codex.git
```

The GitHub Actions workflow checks out the pinned upstream source, applies the
overlay, and builds an unsigned iOS IPA with the Apple iPhoneOS SDK. The IPA is
published as the `amethyst-unsigned-ios-ipa` Actions artifact.

The IPA is ad-hoc/unsigned for distribution purposes. It still needs to be
installed with a signing method such as AltStore, SideStore, Sideloadly, or
another compatible signer.

The overlay adds a built-in external Yggdrasil account flow. It does not store
passwords and keeps the access token in the account credential path used at
launch time.
