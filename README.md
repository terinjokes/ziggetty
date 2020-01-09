# Ziggetty

[Ziggetty](http://ziggetty.terin.ee) is a simple HTTP server for static web sites.

* [Source code](https://git.terinstock.com/plugins/gitiles/ziggetty/)
* [Open changes](https://git.terinstock.com/q/status:open+project:ziggetty)

Ziggetty is written in the [Zig Programming Language](https://ziglang.org/), and currently
requires a version compiled from trunk.

## Quick Start

A development build can be built from the source code:

```console
$ git clone https://git.terinstock.com/ziggetty
$ zig build-exe main.zig
$ ./main &
$ curl http://localhost:8080
```

Tagged releases, along with binaries, will begin shortly.
