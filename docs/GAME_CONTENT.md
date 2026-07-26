# How to add new game content

## Warning

**Never** use other people's images! Avoid using AI whenever possible; a hand-drawn image is always better.

Writing texts yourself is also preferable to generating them using neural networks.

Due to the lack of other options, AI-generated imagery (large images) is permitted for certain illustrative images. This does not apply to in-game images, but rather to illustrations, such as those on the homepage.

## Enemies

To create a new enemy, you need to describe it in [the json file](/priv/enemies/enemies.json) following the example of existing ones, and then add image to [the directory](/priv/tile_images/objects/). For an example of an enemy image, look at [Ghoul image](/priv/tile_images/objects/monster_fish_ghoul.png). Please respect the image size, color palette and drawing style used!

And that's it!

## Buildings/game situations

The game has a template system that allows you to create any possible game situation [with json files](/priv/planet/).

For an example, you can look at existing templates or see the documentation for the [template engine module](/lib/europa/server/planet/templates.ex).

Templates can be variable depending on various conditions, so one template can create many different variations of game situations, for example: a normal house, a burning house, a house with broken walls, a house with monsters, a house with different furniture - all of this can be described in one template.

### Editor

There is also an editor that allows you to view the rendering result of templates. If you have a local copy of the game installed, the editor will be available in the dev environment at http://localhost:4000/admin/templates

## Characters

To add a new character, simply describe it in the [json file](/priv/characters/characters.json). Here is a short description of the format:

```
{
    "name": "Character 1",
    "gender": "male",
    "profession": "Junior research fellow",
    "age_at_disaster": 1,
    "years": {"from": 15, "to": 48},
    "stories": [
        "Story 1",
        "Story 2"
    ],
    "special_stories": {
        "Character 2": [
            "Special story 1",
            "Special story 2"
        ]
    },
    "short_phrases": [
        "Hey!",
        "Is anyone there?"
    ]
}
```

* `name` - character's name
* `gender` - character's gender (`male` or `female`)
* `profession` - character's profession
* `age_at_disaster` - how old was the character at the time of the disaster
* `years` - in what years after the disaster can the character be encountered in the game
* `stories` - list of common character's stories
* `special_stories` - stories that a character will only tell to certain characters (in this case for a character named `Character 2`)
* `short_phrases` - list of short character phrases that are visible without opening a dialogue with them.

The characters on this list are both playable and NPCs. Each game, the player is assigned a random character in a random year of their life. They can meet any other character who lived at the same time and learn lore from them. Situations where characters turn out to be acquaintances, relatives, or colleagues are encouraged, and their interactions can tell the player unique stories about the game's world.

## Loot items

You can add a loot item by [editing the required file in the directory](/priv/items/). Let's look at the example of adding weapons:

1. Go to [weapons.json](/priv/items/weapons.json) file
2. Describe new weapon:

```
{
    "name": "Pistol",
    "shot_cost": {"from": 1, "to": 2},
    "reload_cost": {"from": 1, "to": 2},
    "magazine_size": {"from": 5, "to": 8},
    "accuracy": {"from": 10, "to": 15},
    "caliber": ".40 S&W",
    "rounds_loaded": {"from": 1, "to": {"attr": "magazine_size"}},
    "shooting_type": "bullet",
    "damage": {"from": 8, "to": 11},
    "shooting_distance": {"from": 5, "to": 7},
    "weight": 1.5,
    "image_name": "default_pistol",
    "sound_name": "pistol",
    "random_weight": 2.0
}
```

Description of some notable fields:

* `shot_cost` - cost of a shot (in game turns), the value should be higher for heavy weapons
* `reload_cost` - reload cost (in game turns), the value should be higher for heavy weapons
* `shooting_type` - firing mode: `bullet` for single shots, `burst` for 3-round bursts, `shot` for shotgun blasts (larger area of ​​damage)
* `image_name` - name of the image that will be used for this weapon. The image must be in [the directory](/priv/static/images/). For an example of image size and style, [use the image of a pistol](/priv/static/images/default_pistol.png)
* `sound_name` - name of the MP3 file containing the gunshot sound. The file must be located in [the directory](/priv/static/sounds/). Also, the sound must be registered in [the module](/lib/europa_web/live/game_live.ex).
* `random_weight` - probability of this item dropping. The lower the value, the lower the probability.

To get a description of the format of fields like this `"rounds_loaded": {"from": 1, "to": {"attr": "magazine_size"}}` please look at [module documentation](/lib/europa/tools/attrs_determinator.ex).