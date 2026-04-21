# Europa Torment

Single player browser turn-based survival game that features a loot system, dynamic time of day, health management, procedural generated endless map and more.

![gameplay](/docs/images/gameplay.gif)

**Official game server:** [https://etorment.com](https://etorment.com)

## Current status

Please note that the game is currently in the **early stages of active development** and things are subject to change **rapidly**.

* Some images or sounds may be missing or may reuse existing ones.
* The required amount of content has not yet been added to the game.
* There may be an incorrect balance of game mechanics.
* Some developer guides are incomplete due to things changing frequently.

## Technologies used

The game is developed using the [Elixir language](https://elixir-lang.org/) and the [Phoenix framework](https://phoenixframework.org/) with its remarkable [live_view](https://github.com/phoenixframework/phoenix_live_view). Almost all calculations are server-side, JavaScript is used only when absolutely necessary and is not used for game logic.

## Contribution guides

The game is open source and you can participate in its development.

First, make sure you are familiar with [GitHub contribution guideline](https://docs.github.com/en/get-started/exploring-projects-on-github/contributing-to-a-project)

### How can you help?

#### Game content

If you're interested in creating narrative game content, first of all you need read [lore basics](https://etorment.com/lore) - please follow the timelines described in the game's lore.

Then you can look at [game content guideline](/docs/GAME_CONTENT.md).

#### Improving HTML layouts

The game was initially developed by backend developers who weren't very proficient in frontend development. Therefore, if you're proficient in HTML/CSS/JS - your improvements are highly welcome!

#### Code improvements/new mechanics

If you're an Elixir developer, you can improve the game code, perform optimizations, refactor it, and add new game mechanics. If you have ideas, please first [create an issue](https://github.com/Europa-Torment/europa/issues) describing your proposed improvements and begin development only after discussion. Otherwise, your code may not be accepted.

When changing the code, don't forget to write unit tests and run checks using the `make check-all` command.

#### Text corrections/localization into another language

_Will be described soon._