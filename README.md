# zmenu

![zmenu screenshot](assets/screenshot.png)

## Description

A simple Zig application launcher.

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
```zon
.{
  .terminal = "/bin/ghostty",
  .placeholder = "Search...",
  .prompt = "? ",
  .marker = "> ",
}
```

If yout don't choose a default terminal in zmenu's config, it will try to find a terminal for you.
