# wsz

[![License](https://img.shields.io/github/license/AceHanded/wsz?style=for-the-badge)](https://github.com/AceHanded/wsz/blob/main/LICENSE)
[![Zig Version](https://img.shields.io/badge/zig-0.15.2-yellow?style=for-the-badge&logo=zig)](https://ziglang.org/)
[![GitHubStars](https://img.shields.io/github/stars/AceHanded/wsz?style=for-the-badge&logo=github&labelColor=black)](https://github.com/AceHanded/wsz)
[![BuyMeACoffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/acehand)

An interpreter for the esoteric programming language Whitespace, implemented in Zig.

## Usage

First, download one of the precompiled binaries from the `Releases` section. Alternatively, you can build from source yourself with:

```sh
git clone https://github.com/AceHanded/wsz.git
cd wsz
zig build
```

After that, a file containing Whitespace code may be run with:

```sh
wsz <file>
```

The `examples/` folder contains sample Whitespace programs that can be used for testing.
