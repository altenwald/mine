# Mine

Mine Sweeper typical game but using terminal and developed using Elixir.

If you love this content and want we can generate more, you can support us:

[![paypal](https://www.paypalobjects.com/en_US/GB/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=XK6Z5XATN77L2)

## Getting started

You only need to clone this repository, and compile it. Ensure you have installed Elixir 1.8+ and Erlang 20+. This was developed using Erlang 22.0 and Elixir 1.8.2.

```
git clone https://github.com/altenwald/mine.git
cd mine
iex -S mix run
```

Once you are inside of the Elixir shell you can use the module `Mine` to interact with the game. You can start or restart the game whenever using this function:

```elixir
Mine.restart
```

To discover a cell use:

```elixir
Mine.sweep 1, 1
```

You have to pass the X and Y coords. When you find or you think you have a flag you can mark it as:

```elixir
Mine.flag 2, 5
```

You can see here an example:

[![Mine Sweeper](screenshot.png)](screenshot.png)

You can open an issue, pull request or send us a comment when you want.

Enjoy!
