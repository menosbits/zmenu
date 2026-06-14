# zmenu
![Static Badge](https://img.shields.io/badge/Zig-v.0.16.0-%23F7A41D?style=for-the-badge&logo=zig&logoColor=%23F7A41D&color=%23F7A41D)
![Static Badge](https://img.shields.io/badge/tests-passing-black?style=for-the-badge&label=Tests&color=green)

![zmenu screenshot](assets/screenshot.png)

## Description

A simple Zig application launcher for GNU/Linux.

I've always loved using a terminal. Most of applications launcher are GUI apps. Why not use a terminal one?

In tiled wayland compositor or tiled window manager, all you need is a terminal!

## Documentation:

`zmenu` depends on XDG_CONFIG_HOME variable. Make sure you have the following line in your shell configuration:

```bash
export XDG_CONFIG_HOME=$HOME/.config
```

The default zmenu's config file is located in `$XDG_CONFIG_HOME/zmenu/zmenu.zon`. It uses the zon format.

You can choose the default terminal, search bar prompt and placeholder, and the result list marker.

Here's an example:
```zig
.{
  .terminal = "/bin/ghostty",
  .placeholder = "Search...",
  .prompt = "? ",
  .marker = "> ",
}
```

If yout don't choose a default terminal in zmenu's config, it will try to find a terminal for you.

## License

MIT License. Check it [here](LICENSE).

## Acknowledgments

- [zigzag](https://github.com/meszmate/zigzag) - A delightful TUI framework for Zig, inspired by Bubble Tea and Lipgloss.
- [uni](https://github.com/menosbits/uni) - `uni` is a Zig library that lets you easily colorize your strings and outputs on your code. It uses ANSI escape codes to put color and styles in your strings and outputs.
