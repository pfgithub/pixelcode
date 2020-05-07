# pixelcode

<p align="center">
	<img src="https://raw.githubusercontent.com/pfgithub/pixelcode/master/.github/demo.png" alt="">
</p>

## building

Requires [https://www.raylib.com/](raylib)

```bash
./deps/download.sh
zig build run
```

## notes

- uses [tree-sitter-zig](https://github.com/GrayJack/tree-sitter-zig) which is slightly out of date. does not support editing text yet.
- font uses 6x12 characters. centered 4x4 for lowercase, +3 up for uppercase and tall lowercase characters, +3 down for bottoms of lowercase characters, 1 pixel padding for overlapping bits at the edges of special characters.