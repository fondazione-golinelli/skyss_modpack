## 1. Audio_lib

Audio_lib is a library to easily manage the audio system of your game and mods, featuring accessibility options. Minetest Game sounds natively supported.  

### 1.1. Music types
The strong point of audio_lib is that it categorises sounds according to their type. This allows manipulation of category-specific audio settings (e.g. background music) without altering the rest (e.g. sound effects).

By default there are two music types: `"bgm"` (background music) and `"sfx"` (sound effects). However, it's possible to add custom types.

#### 1.1.1 BGM
Background music acts in a peculiar way: audio_lib won't allow the overlapping of two or more bgm, meaning it won't reproduce more tracks at the same time. Why? Well, because it'd be unusual to have more background tracks running together :D  
Background music is always `loop = true`, but it can be overwritten with the `override_params` attribute in `play_bgm(..)` function

#### 1.1.2 SFX
Sound effects are a common type in videogames, hence provided by default. Use this type for short sounds like a door closing. Sound effects are always `loop = false`

#### 1.1.3 Custom types
Custom types have no built-in rules and they can be used to add more layers to your sound management system. Useful types could be "ambient", "dialogues", "notifications". To register one, do:
```lua
audio_lib.register_type(mod, s_type, <readable_names>)
```

`mod` is the technical name of your mod, `s_type` is the technical name of the type (only lowercase letters, numbers and underscores allowed); `readable_names` is a table `{mod = name, type= name}` for human readable names. Multiple mods might register the same type: in this case they will co-exist, but only the first readable name will be used (first as in, according to the mod registration order).

### 1.2 Registering new sounds
Sounds must be registered before using them, as audio_lib stores their data in a local table. To do that:
* `audio_lib.register_sound(type, track_name, desc, <def>, <duration>)`: registers a new sound of type `type` (see [1.1 Music types](###11-music-types)), using `track_name` audio file.
  * `desc` is a short description of the sound, used for accessibility options
    * If you want to use the same sound for two different occasions and you forcibly need two different descriptions, use two different audio files and register them separately. It's a cleaner solution than introducing an extra parameter with its own special behaviour
  * `def` an audio_lib sound parameter table (see next section)
    * `pos`, `object`, `to_player`, `to_players` and `exclude_player` won't work during the registration. If it's a bgm, nor will `loop = false`. If it's an sfx, nor will `loop = true`
  * `duration` (float) is a temporary minimal solution [waiting for Minetest](https://github.com/minetest/minetest/issues/12375) and it's the length of the track in seconds. Default is `1`
    * Doesn't work for type `"bgm"`
    * Idea n°1 is to allow accessibility panels to know when they're supposed to disappear: since they last at least one second, the rule of thumb is to avoid declaring it if the track is shorter than 1 second; unless...
    * Idea n°2. In case of short sounds with `cant_overlap = true`, it allows audio_lib to know when the sound actually finished. So the mod can tell if it's possible to start the new instance or not.
    * This feature might be incomplete as, once again, I'm waiting for Minetest to implement it as a built-in feature
  * if the same sound is registered more than once, it'll just get overridden by the last function call featuring it

#### 1.2.1 Audio_lib sound parameter table
An audio_lib sound parameter table is the sum of Luanti [Sound parameters table](https://github.com/minetest/minetest/blob/master/doc/lua_api.md#sound-parameter-table) (`pos`, `object` etc.) and a few custom fields. Namely:
* `to_players`: (table) send the sound to more players, format `{p_name, another_name}`. It's highly recommended to use this parameter instead of looping `p_name`s and creating multiple audio_lib calls. Default is `nil`
* `exclude_players`: (table) same as in `to_players` but for players to exclude
* `ephemeral`: (boolean) whether the sound shouldn't be trackable, so it can't be altered during its lifetime. Default is `true`
* `cant_overlap`: (boolean) whether playing the sound whilst it's already being played will stop the first instance or it'll overlap the two. It requires the sound not to be ephemeral. Default is `nil`
  * BEWARE: this will only work if `duration` is declared in the sound registration, or if more than one second has passed since the first instance
  * In case of `pos` or `obj` being declared, the sound won't overlap only if there is already a sound being played at that `pos`/`obj` for the player



Some examples:
```lua
-- register a bgm
audio_lib.register_sound("bgm", "mymod_bgm1", "The adventure begins")

-- register an sfx and tweaks its parameters
audio_lib.register_sound("sfx", "mymod_sfx1", "Door closing", {gain = 1.2, pitch = 0.9})

-- register a sound for the custom type "ambient"
audio_lib.register_sound("ambient", "mymod_spookyambient", "Eerie sound")
```

When you want to use a sound in the audio_lib functions, simply use the `track_name` name you've used during the registration.

#### 1.2.2 Registering sound variants
audio_lib uses the Luanti native [sound groups system](https://github.com/minetest/minetest/blob/master/doc/lua_api.md#sound-group); simply register a sound as usual and then put as many audio files you need in the designated folder by following Luanti syntax

### 1.3 Utils
* `audio_lib.play_bgm(p_name, track_name, <override_params>)`: plays `track_name`, if registered, to `p_name`.
  * `override_params` is an audio_lib parameters table that, if declared, will override the default Luanti parameters of `track_name` (e.g. if `track_name` is registered with `gain = 0.8`, declaring `gain = 0.5` won't be result in `gain = 0.4` (0.8 * 0.5), but in 0.5 (1.0 * 0.5))
  * if `track_name` is the track that's already being played, nothing will happen
* `audio_lib.change_bgm_volume(p_name, gain, <fade_duration>)`: change the volume of the bgm `p_name` is listening to, if any. `fade_duration` is the seconds needed to reach such volume (`0` by default)
* `audio_lib.continue_bgm(p_name)`: resumes the last bgm `p_name` previously heard, starting from where it had left (MT 5.8+)
* `audio_lib.stop_bgm(p_name, <fade_duration>)`: interrupts the bgm `p_name` was currently listening to, if any. Specify a number for `fade_duration` for a fade out effect
* `audio_lib.play_sound(track_name, <override_params>)`: plays sounds that are sfx or custom types. See `play_bgm(..)` for `override_params`.
  * Sfx can't be looped, no matter what's declared in the function
  * If ephemeral, it can't be stopped
  * if you're passing an `object` or a `pos` that don't exist, the sound will be played server-wide. For this reason it's good practice to check the existence of these values before actually calling the function
* `audio_lib.stop_sound(p_name, track_name)`: stop the custom sound `track_name` for `p_name`, if any. Basic implementation, it can't distinguish between two sounds played close to each other.
  * Waiting for https://github.com/minetest/minetest/issues/12375 for a proper implementation. The same applies to a fade duration and a hypothetical `change_sound_volume(..)`
* `audio_lib.reload_music(p_name, old_settings)`: applies to `p_name` their new audio settings at runtime. `old_settings` is needed for calculation
* `audio_lib.is_sound_registered(track_name, <type>)`: returns whether the specified track name exists within audio_lib or not
* `audio_lib.open_settings(p_name)`: opens the audio settings formspec for `p_name`

### 1.4 Getters
* `audio_lib.get_player_bgm(p_name, <in_detail>)`: returns the name of the bgm file currently played for `p_name`.
  * If `in_detail` is `true`, it returns a table instead. The table contains in-depth information about the track. Namely:
    ```lua
    {
      -- name of the file
      name = "",
      -- description put in the registration
      description = "",
      -- sound handle
      handle = 7,
      -- default MT sound parameters
      params = {}
    }
    ```
* `audio_lib.get_player_sounds(s_type, p_name, <in_detail>)`: returns a table of names of the sound files of type `s_type` (`"sfx"` or custom types) currently played for `p_name`.
  * If more instances of the same sound are played, audio_lib will register and print them as `"name__1"`, `"name__2"` etc.
  * If `in_detail` is `true`, it returns a table of tables instead. Those contain in-depth information about each track. Namely:
    ```lua
    {
      -- name of the file
      name = "",
      -- description put in the registration
      description = "",
      -- default MT sound parameters
      params = {}
    }
    ```
  * Due to current engine limitations, there's no way to know when a track really ends, so every non-bgm sound is kept in memory for 1s. This is needed: https://github.com/minetest/minetest/issues/14022
  * Currently it's not possible to keep track of the same sound played more times in less than a second, so it'll only return the data of the last one
* `audio_lib.get_types()`: returns a table with all the registered custom types with the format `{"technical_name1", "technical_name2"}`. It returns an empty table if no custom types are found
* `audio_lib.get_type_name(s_type)`: returns the human readable name of custom type `s_type`
* `audio_lib.get_mods_of_type(s_type)`: returns a table containing the technical name of mods that have registered `s_type`. Format `{name = true}`
* `audio_lib.get_settings(p_name)`: returns a table containing `p_name` settings

### 1.5 Accessibility
`audio_lib` features a builtin accessibility option, to activate via `/audiosettings`. In case you want to customise the default implementation, do so by overriding the following functions:
* `audio_lib.HUD_accessibility_create(p_name)`: run when the player joins
* `audio_lib.HUD_accessibility_remove(p_name)`: run when the player leaves
* `audio_lib.HUD_accessibility_play(p_name, s_type, audio)`: run when an audio track is played
* `audio_lib.HUD_accessibility_stop(p_name, s_type, track_name)`: run when an audio track is stopped (not called when it ends on its own)



## 2. About the author
I'm Zughy, a professional Italian pixel artist who fights for free software and digital ethics. If this library spared you a lot of time and you want to support me somehow, please consider donating on [Liberapay](https://liberapay.com/Zughy/)
