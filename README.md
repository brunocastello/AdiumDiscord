# Discord for Adium

> [!CAUTION]
> ### 🤖 AI-Generated Code Ahead
> **This entire repository was crafted with the help of AI.**
>
> If you are allergic to neural networks, synthesized functions, or autocomplete on steroids, **this repository is not for you**.
> You are kindly invited to close this page and write your code line-by-line in `ed` or `vim`. Everyone else, enjoy!

Discord for Adium 1.5.10 on Mac OS X 10.6 Snow Leopard. It's
[purple-discord](https://github.com/EionRobb/purple-discord), the Discord plugin for Pidgin, packaged
as an Adium plugin.

## You need

- Mac OS X 10.6.8 with Adium 1.5.10
- A TLS 1.2 update such as AquaTransport. Discord won't talk to stock 10.6 without one.

## Install

1. Download `Discord-<version>.zip` from [Releases](../../releases) and unzip it.
2. Double-click `Discord.AdiumLibpurplePlugin`.
3. Restart Adium and add a Discord account in **Preferences → Accounts**.

## Logging in

Use your Discord email and password. If you have 2FA, Adium asks for the code from your
authenticator app. After that the plugin saves your login in the Keychain, so you don't need the
password or the code again.

If Discord asks for a CAPTCHA, paste your Discord token into the password field instead. You can
copy it from the `Authorization` header of any `discord.com/api` request in your browser's developer
tools.

## What works

- Direct messages and your status (Online, Idle, Do Not Disturb, Invisible)
- Server channels: **File → Join Group Chat**, then pick a server and a channel, or paste a channel
  link. A channel also opens when someone @mentions you in it.
- Group DMs, listed under **Group DMs** in the same window. Not tested yet, so reports are welcome.

Voice, video, QR-code login and SMS or security-key 2FA aren't supported.

Third-party clients are against Discord's terms of service. Use this at your own risk.

## Building

GitHub Actions builds every push and makes a release for each `vX.Y.Z` tag. The build
cross-compiles on Linux against the 10.6 SDK, because current Xcode can't link i386.

On a Mac you can build just the x86_64 part:

```sh
git submodule update --init
./scripts/fetch-deps.sh
make ARCHS=x86_64
```

## License

GPLv3, like purple-discord.
