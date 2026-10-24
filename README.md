# Discord for Adium 1.5.10

An Adium plugin that adds a **Discord** account type to Adium 1.5.10, the last Adium release for
Mac OS X 10.6 Snow Leopard. It wraps [purple-discord](https://github.com/EionRobb/purple-discord)
(the libpurple Discord plugin used by Pidgin) in the small Objective-C layer Adium needs.

Status: early. Builds for i386 and x86_64; needs testing on real 10.6 machines.

## Requirements

- Mac OS X 10.6.8 with Adium 1.5.10
- TLS 1.2 support for Adium's connections (Discord sits behind Cloudflare). Stock 10.6 does not
  have it; a TLS update such as AquaTransport is needed.

## Install

1. Download `Discord-<version>.zip` from the
   [Releases](../../releases) page (or the latest Actions build) and unzip it.
2. Double-click `Discord.AdiumLibpurplePlugin`, or copy it to
   `~/Library/Application Support/Adium 2.0/PlugIns/`.
3. Restart Adium, then add an account under **Preferences → Accounts → + → Discord**.

## Logging in

- **Email + password.** Enter your Discord email and password. If you use two-factor
  authentication, Adium asks for the code. After the first successful login the session token
  Discord issues is saved in your Keychain ("Adium Discord token"), so later logins skip the
  password and 2FA.
- **Token.** If Discord demands a CAPTCHA ("Need CAPTCHA to login"), log in with a token instead:
  sign in to Discord in a modern browser, open the developer tools, and copy the `Authorization`
  header of any request to `discord.com/api`. Paste that token into Adium's **password** field.

If Discord stops accepting a saved token, the plugin forgets it and Adium asks for the password again.

Discord's terms of service do not allow third-party clients, whichever way you log in. Use it at
your own risk.

## What works / what doesn't (yet)

- Direct messages, presence (Online / Idle / Do Not Disturb / Invisible)
- Server channels: **File → Join Group Chat…**, pick the Discord account, then a server and one
  of its channels. You can also paste a channel link (right-click a channel in Discord → Copy
  Link) or a channel ID. Channel windows are titled "#channel (Server)".
- Server channels also open by themselves when you are @mentioned in them.
- Group DMs: they open when someone writes in them, and are listed under **Group DMs** at the top
  of the server menu in **File → Join Group Chat…** (newest activity first). Not yet tested on a
  real group DM; reports welcome.
- Not yet: voice/video, QR-code login, security-key (WebAuthn) or SMS two-factor login.

## Building

CI builds every push with GitHub Actions (`.github/workflows/build.yml`): it cross-compiles on
Linux with [osxcross](https://github.com/tpoechtrager/osxcross) against the Mac OS X 10.6 SDK,
because current Xcode can no longer link i386. Tag `vX.Y.Z` to publish a release.

Locally on a Mac you can build the x86_64 slice only:

```sh
git submodule update --init
./scripts/fetch-deps.sh     # 10.6 SDK + Adium 1.5.10 frameworks into deps/
make ARCHS=x86_64
```

`fetch-deps.sh` takes libpurple 2.10.7, glib 2.38 and json-glib 0.9.2 (binaries and headers)
from the Adium 1.5.10 source tree, and the Adium, AdiumLibpurple and AIUtilities framework
binaries from the official Adium 1.5.10 disk image.

## License

GPLv3, like purple-discord. Adium is GPLv2-or-later.
