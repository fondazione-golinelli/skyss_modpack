-- Content of the teacher guide (guide.lua).
--
-- Chapters hold pages; a page has a title, an optional figure drawn above the
-- text and a body made of blocks:
--   { "h", text }                 heading
--   { "p", text }                 paragraph
--   { "steps", { text, ... } }    numbered steps
--   { "keys", { {key, text} } }   keys or commands with what they do
--   { "defs", { {term, text} } }  terms with their explanation
--   { "imgs", { {texture, text} } } small pictures with a caption
--   { "tip", text }               highlighted tip
--   { "links", { page_id, ... } } links to other pages
-- Figures: { kind, h = height, ... } (see the figure functions in guide.lua).
-- Texts are in English and translated through the classrooms_guide domain;
-- they must not contain "=" (the .tr key separator).

local G = minetest.get_translator("classrooms_guide")

local KEY_SPACE, KEY_SHIFT = G("Space"), G("Shift")

return {
    -- ── Getting started ──────────────────────────────────────────────────
    { id = "start", title = G("Getting started"), pages = {
        { id = "welcome", title = G("Welcome to Skyss"),
          body = {
            { "p", G("This guide explains everything you need to run a lesson in Skyss: the game controls, the basics of Mineclonia, some classic activities and every function of the class panel.") },
            { "p", G("Choose a chapter on the left. Use Previous and Next at the bottom to read the pages in order, or click the blue links to jump to a topic.") },
            { "h", G("Where to start") },
            { "links", { "tools", "roles", "move", "open", "new_world", "live", "checklist" } },
            { "tip", G("The guide is always in your hotbar, also during a lesson: open it whenever you need it.") },
          } },
        { id = "tools", title = G("Your tools"),
          figure = { "toolbar", h = 1.9 },
          body = {
            { "p", G("Class staff get some fixed tools at the end of the hotbar. They cannot be dropped or lost: if one disappears, it comes back by itself within a second. Click or right-click a tool to use it.") },
            { "imgs", {
                { "classrooms_bridge_class_panel.png", G("Class Panel: your classes, students, worlds and the live controls of the lesson.") },
                { "classrooms_bridge_blockexchange.png", G("BlockExchange Library: places ready-made buildings and shares yours. Only in class worlds.") },
                { "classrooms_bridge_world_tools.png", G("World Tools: zones, missions, map, rules, time and weather of the world you are in. Only in the class worlds you manage.") },
                { "classrooms_bridge_guide.png", G("Teacher guide: this manual.") },
            } },
            { "p", G("Students carry other tools: the World Map in class worlds, to see zones and teleport points, and Class worlds in the HUB, to enter the worlds that are open. Visitors get a door to go back to the HUB.") },
            { "tip", G("Slots 1 to 9 stay free for blocks and items: the tools never take their place.") },
          } },
        { id = "roles", title = G("Who does what"),
          body = {
            { "defs", {
                { G("Teacher"), G("Creates the class and its worlds, adds the students and has every control. The teacher who creates a class is its owner.") },
                { G("Co-teacher"), G("A teacher linked to the class: same controls as the owner, but cannot delete the class.") },
                { G("Assistance"), G("Helps during the lesson: adds and removes students, teleports to online students and joins the running worlds of the class. Cannot create worlds, change the rules or freeze the class.") },
                { G("Student"), G("Plays in the class worlds. Joins as a student while someone of the class staff is inside the world; otherwise visits as a spectator.") },
                { G("Spectator"), G("Whoever visits a world from the HUB portal without being part of it: flies and passes through blocks, but cannot build.") },
            } },
            { "tip", G("In class worlds teachers and Assistance are always in creative mode and can fly; in the HUB they go back to normal mode.") },
          } },
    } },

    -- ── Controls ─────────────────────────────────────────────────────────
    { id = "controls", title = G("Controls"), pages = {
        { id = "move", title = G("Moving and looking around"),
          figure = { "keyboard", h = 3.75, keys = { "W", "A", "S", "D", "E", "Space", "Shift", "Esc" },
                     mouse = { left = true, right = true } },
          body = {
            { "keys", {
                { "W A S D", G("Walk forward, left, back and right.") },
                { G("Mouse"), G("Look around.") },
                { KEY_SPACE, G("Jump; in water, swim up.") },
                { KEY_SHIFT, G("Sneak: you do not fall off edges. While flying, go down.") },
                { "E", G("Hold it while walking forward to sprint.") },
                { G("Left click"), G("Dig a block or hit.") },
                { G("Right click"), G("Place a block or use something: doors, chests, buttons...") },
                { "Esc", G("Close a window or open the game menu.") },
            } },
            { "tip", G("Keys can be changed from the game menu (Esc), in Settings, Controls. This guide uses the standard keys.") },
          } },
        { id = "fly", title = G("Flying, speed and passing through blocks"),
          figure = { "keyboard", h = 3.75, keys = { "K", "J", "H", "E", "Space", "Shift" } },
          body = {
            { "keys", {
                { "K", G("Flying on/off. Space goes up, Shift goes down.") },
                { "J", G("Fast mode on/off: while flying you move much faster; on the ground, hold E to run fast.") },
                { "H", G("Noclip on/off: pass through blocks and walls while flying.") },
            } },
            { "p", G("Teachers and Assistance can always fly, move fast and pass through blocks in class worlds. Students can fly only if you allow it in the world rules (Students can fly); they never pass through blocks.") },
            { "p", G("Flying players never get hurt or hungry.") },
            { "tip", G("Stuck underground? Press K and then H, fly up through the ground and press H again once you are out.") },
          } },
        { id = "inventory", title = G("Inventory and hotbar"),
          figure = { "keyboard", h = 3.75, keys = { "I", "Q", "1", "2", "3", "4", "5", "6", "7", "8", "9" },
                     mouse = { wheel = true } },
          body = {
            { "keys", {
                { "I", G("Open the inventory.") },
                { G("1 to 9, wheel"), G("Choose a slot of the hotbar.") },
                { "Q", G("Drop the item in your hand.") },
            } },
            { "p", G("In the inventory you move items by clicking: left click takes the whole stack, right click takes half of it or puts down one item at a time. Shift and click moves a stack straight between the inventory and a chest.") },
            { "p", G("In creative mode the inventory shows every block of the game, split into tabs: building blocks, decoration, tools, food... The search tab finds a block by name: drag it into your hotbar.") },
            { "tip", G("In creative mode, drop an item on the trash slot of the inventory to get rid of it.") },
          } },
        { id = "chat", title = G("Chat and commands"),
          figure = { "keyboard", h = 3.75, keys = { "T", "/", "F2" } },
          body = {
            { "keys", {
                { "T", G("Open the chat and write to everyone in the same world.") },
                { "/", G("Open the chat with a command already started.") },
                { "F2", G("Show or hide the chat.") },
            } },
            { "h", G("Useful commands") },
            { "keys", {
                { "/classes", G("Opens the class panel, like the Class Panel tool.") },
                { "/lobby", G("Goes back to the HUB from any world. Students can use it too.") },
                { "/freeze", G("Followed by the name of a student or of a class: freezes them.") },
                { "/unfreeze", G("Followed by the same name: unfreezes them.") },
            } },
            { "p", G("Messages sent by the panel, for example when you freeze the class or teleport the students, appear in the students' chat marked [Teacher].") },
          } },
        { id = "screen", title = G("Screen and camera"),
          figure = { "keyboard", h = 3.75, keys = { "C", "F1", "F5", "F11", "F12", "+", "-" } },
          body = {
            { "keys", {
                { "C", G("Change the camera: first person, from behind, from the front.") },
                { "F1", G("Hide the interface, for clean pictures or for the projector.") },
                { "F5", G("Show your coordinates and other information.") },
                { "F11", G("Full screen.") },
                { "F12", G("Take a screenshot (saved in the screenshots folder of Luanti).") },
                { "+ / -", G("See farther or closer (viewing range).") },
            } },
            { "tip", G("With a projector, press F1 to hide the hotbar and C to show your character from behind while you explain.") },
          } },
    } },

    -- ── Mineclonia basics ────────────────────────────────────────────────
    { id = "basics", title = G("Mineclonia basics"), pages = {
        { id = "blocks", title = G("Breaking and placing blocks"),
          figure = { "items", h = 2.0, items = {
              { "mcl_core:dirt_with_grass", G("Break") },
              { "mcl_tools:pick_stone", G("Pickaxe") },
              { "mcl_tools:axe_wood", G("Axe") },
              { "mcl_core:cobble", G("Place") },
          } },
          body = {
            { "p", G("Hold the left button on a block to break it. In creative mode it breaks at once; in survival mode the right tool is faster: a pickaxe for stone, an axe for wood, a shovel for soil and sand.") },
            { "p", G("To place a block, choose it in the hotbar and right-click on the side of another block: the new block goes against that side.") },
            { "p", G("Hold Shift while placing: you do not fall off the edge, and you can place blocks against chests, doors or other blocks you could open.") },
            { "tip", G("Students cannot build in zones reserved to others, or when the world is locked: a message tells them why.") },
          } },
        { id = "modes", title = G("Creative and survival"),
          body = {
            { "defs", {
                { G("Creative mode"), G("Unlimited blocks from the inventory, blocks break at once, no damage. Teachers are always in creative mode in class worlds; students only if you allow it (Student creative mode in the world rules).") },
                { G("Survival mode"), G("Players collect resources, craft their tools and have health and hunger bars. It is the classic way to play, perfect for activities about resources and cooperation.") },
            } },
            { "p", G("Damage, hunger and fights between players depend on the world rules: new worlds start safe, with all of them off.") },
            { "links", { "rules", "survival_start" } },
          } },
        { id = "crafting", title = G("Crafting"),
          figure = { "items", h = 2.0, items = {
              { "mcl_trees:tree_oak", G("Logs") },
              { "mcl_trees:wood_oak", G("Planks") },
              { "mcl_crafting_table:crafting_table", G("Crafting table") },
              { "mcl_core:stick", G("Sticks") },
              { "mcl_tools:pick_wood", G("Tools") },
          } },
          body = {
            { "steps", {
                G("Break a tree to get logs."),
                G("Put the logs in the crafting grid of the inventory: they become planks."),
                G("Four planks make a crafting table: place it and right-click it to use the larger 3×3 grid."),
                G("Two planks, one above the other, make sticks: they are needed for tools and torches."),
            } },
            { "p", G("In the inventory, the Recipe book button shows how to make every item: click an item to see its recipe.") },
            { "tip", G("In creative mode crafting is not needed, but it is a great activity for survival lessons.") },
          } },
        { id = "chests", title = G("Chests"),
          figure = { "items", h = 2.0, items = {
              { "mcl_chests:chest", G("Chest") },
          } },
          body = {
            { "p", G("Place a chest and right-click it to open it: it holds 27 stacks of items. Two chests placed side by side become a large chest.") },
            { "p", G("Hold Shift while clicking a stack to move it at once between the chest and your inventory.") },
            { "p", G("In missions, the delivery chest is special: it accepts only the items the mission asks for, and counts what the students bring.") },
            { "links", { "missions" } },
            { "tip", G("A chest is a good way to hand out materials: fill one before the lesson and place it at the arrival point.") },
          } },
        { id = "signs", title = G("Signs"),
          figure = { "items", h = 2.0, items = {
              { "mcl_signs:wall_sign_oak", G("Sign") },
              { "mcl_dyes:red", G("Dye") },
              { "mcl_mobitems:glow_ink_sac", G("Glow ink sac") },
          } },
          body = {
            { "p", G("Place a sign on a wall or on the ground: a window opens where you write its text.") },
            { "p", G("Write carefully before closing the window: a sign cannot be changed later. To correct it, break it and place a new one.") },
            { "p", G("Right-click a sign holding a dye to change the colour of the text, or holding a glow ink sac to make it readable in the dark.") },
            { "tip", G("Signs are perfect as labels: names of buildings, instructions for a station, questions for the students.") },
          } },
        { id = "books", title = G("Books"),
          figure = { "items", h = 2.0, items = {
              { "mcl_books:writable_book", G("Book and quill") },
              { "mcl_books:written_book", G("Written book") },
              { "mcl_lectern:lectern", G("Lectern") },
          } },
          body = {
            { "p", G("A book and quill is a notebook: hold it and right-click to write. You can change the text as many times as you want.") },
            { "p", G("When it is finished, press Sign, give it a title and confirm: it becomes a written book with your name, which everyone can read but nobody can change.") },
            { "p", G("Put a written book on a lectern so the whole class can read it in the same place.") },
            { "tip", G("Students can keep a diary of the activity in a book and quill, and sign it at the end as their report.") },
          } },
    } },

    -- ── Game activities ──────────────────────────────────────────────────
    { id = "play", title = G("Game activities"), pages = {
        { id = "farm", title = G("Building a farm"),
          figure = { "farm", h = 3.9 },
          body = {
            { "steps", {
                G("Choose a flat place, dig a hole one block deep in the middle and fill it with a water bucket."),
                G("Use a hoe on the grass or dirt around the water: it becomes farmland. Water keeps the soil wet up to 4 blocks away, so a 9×9 square with water in the middle is perfect."),
                G("Right-click the farmland with seeds to plant them. Wheat seeds come from breaking tall grass; carrots and potatoes are planted as they are."),
                G("Crops need light: in the dark they stop growing. Put torches around the field."),
                G("Bone meal makes a plant grow at once: right-click the plant with it."),
                G("When the wheat is golden, break it: you get wheat and new seeds to plant again."),
            } },
            { "tip", G("Farmland turns back into dirt if you place a block on it. Build a fence around the field to keep animals out.") },
          } },
        { id = "animals", title = G("Raising animals"),
          figure = { "items", h = 2.0, items = {
              { "mcl_farming:wheat_item", G("Cows, sheep") },
              { "mcl_farming:wheat_seeds", G("Chickens") },
              { "mcl_farming:carrot_item", G("Pigs") },
              { "mcl_fences:oak_fence", G("Fence") },
              { "mcl_tools:shears", G("Shears") },
          } },
          body = {
            { "p", G("Animals follow you if you hold their favourite food: wheat for cows and sheep, seeds for chickens, carrots or potatoes for pigs.") },
            { "p", G("Feed two animals of the same kind: they have a baby. Build a fence around the pen so the animals stay inside.") },
            { "p", G("Shears take wool from sheep without hurting them; an empty bucket on a cow gives milk.") },
            { "tip", G("With the Animals goal of a mission, students must bring a number of animals into a zone or near the delivery chest.") },
            { "links", { "missions" } },
          } },
        { id = "survival_start", title = G("First steps in survival"),
          figure = { "items", h = 2.0, items = {
              { "mcl_tools:pick_wood", G("Wooden pickaxe") },
              { "mcl_core:cobble", G("Cobblestone") },
              { "mcl_torches:torch", G("Torch") },
              { "mcl_furnaces:furnace", G("Furnace") },
              { "mcl_farming:bread", G("Food") },
          } },
          body = {
            { "steps", {
                G("Break a tree with your hands to get logs, then make planks and a crafting table."),
                G("Make a wooden pickaxe and dig stone: with cobblestone you make better tools."),
                G("Before night, build a small shelter and make torches with coal and sticks."),
                G("Eat when the hunger bar goes down: apples, bread, cooked meat. Food is cooked in a furnace, made with 8 cobblestones."),
            } },
            { "tip", G("For younger classes keep damage and hunger off: students still collect and build as in survival.") },
          } },
        { id = "night", title = G("Night, monsters and safety"),
          figure = { "items", h = 2.0, items = {
              { "mcl_torches:torch", G("Light") },
          } },
          body = {
            { "p", G("A day in the game lasts about 20 minutes. At night hostile monsters appear in dark places, if the world allows them.") },
            { "p", G("New class worlds have only peaceful mobs: no zombies, skeletons or creepers. You can change this in the world rules (Only peaceful mobs); it applies after a restart.") },
            { "p", G("Explosions break blocks is off in new worlds, so TNT and creepers cannot destroy the students' builds.") },
            { "p", G("If the night disturbs the lesson, choose Day and Pause time in Time & weather: it stays light until you let time flow again.") },
            { "links", { "time", "rules" } },
          } },
    } },

    -- ── Class panel: class and people ────────────────────────────────────
    { id = "panel", title = G("Class panel: people"), pages = {
        { id = "open", title = G("Opening the class panel"),
          figure = { "class_view", h = 4.3 },
          body = {
            { "p", G("Click the Class Panel in your hotbar, or type /classes in the chat. Inside a class world it opens straight on that class; elsewhere it shows the list of your classes.") },
            { "h", G("Your classes") },
            { "p", G("Type a name (for example 3B Science) and press Create class. Each card shows how many students are online and how many worlds are running. To delete a class click the bin twice: its worlds are deleted too.") },
            { "h", G("The class view") },
            { "p", G("On the left: the live controls and the students. On the right: the world you are in and all the worlds of the class. At the top: Minigames and Return to HUB.") },
            { "tip", G("Hold the mouse on a button to read a short explanation of what it does.") },
          } },
        { id = "students", title = G("Adding students"),
          body = {
            { "p", G("In the class view press Manage people: the Students tab opens.") },
            { "h", G("A student who already has an account") },
            { "p", G("Under Add an existing player, type the username they log in with and press + Add.") },
            { "h", G("A new student") },
            { "steps", {
                G("Under Create a new account, type the username: from 1 to 20 letters, numbers, - or _ (no spaces)."),
                G("Type the password twice: at least 8 characters."),
                G("Press Create and add to the class. Give the student the username and the password: they log in normally with them."),
            } },
            { "p", G("On the right you see the whole class, with a search box, who is online and their group. The bin removes a student from the class; the account is not deleted.") },
            { "tip", G("A student can be in only one class at a time.") },
          } },
        { id = "passwords", title = G("Student passwords"),
          body = {
            { "p", G("If a student forgets the password, open Manage people, Students: next to the students whose account you created there is a padlock.") },
            { "steps", {
                G("Click the padlock next to the student."),
                G("Type the new password twice (at least 8 characters)."),
                G("Confirm: the new password works from the next login. A student who is playing is not disconnected."),
            } },
            { "p", G("You can change only the passwords of the accounts you created from the panel. For the other accounts, ask an administrator.") },
          } },
        { id = "staff", title = G("Co-teachers and assistance"),
          body = {
            { "p", G("Manage people has two more tabs for the adults of the class:") },
            { "defs", {
                { G("Teachers"), G("Add a colleague by username: they get the same controls as you on this class. If they are not a teacher yet, they become one.") },
                { G("Assistance"), G("Add an assistant (an educator, a tutor, a helper): they can add students, teleport to them and join the class worlds, but cannot change worlds or rules.") },
            } },
            { "tip", G("The class always remains owned by the teacher who created it.") },
          } },
        { id = "groups", title = G("Teams (groups)"),
          body = {
            { "p", G("Groups split the class into coloured teams, for example to give each team its own building zone or mission. Open Manage people, Groups.") },
            { "steps", {
                G("Type a name under New group and press + Create (up to 12 groups)."),
                G("On the right, tick the students to move: search, the filter and Select shown help with long lists."),
                G("In the bar at the bottom choose the group and press Apply."),
            } },
            { "p", G("Each group card has Show (lists only its students), Bring (teleports its online students to you), Freeze and delete. Deleting a group keeps its students in the class, but removes its zones.") },
            { "tip", G("In the class view, the filter above the students shows a single group.") },
          } },
    } },

    -- ── Class panel: worlds and lessons ──────────────────────────────────
    { id = "session", title = G("Class panel: worlds and lessons"), pages = {
        { id = "new_world", title = G("Creating a class world"),
          figure = { "images", h = 2.1, images = {
              { "classrooms_bridge_guide_map_flat.png", G("Flat World") },
              { "classrooms_bridge_guide_map_generic.png", G("Generic World") },
              { "classrooms_bridge_guide_map_italy.png", G("Countries") },
              { "classrooms_bridge_guide_map_europe.png", G("Europe") },
              { "classrooms_bridge_guide_map_moon.png", G("Moon") },
              { "classrooms_bridge_guide_map_mars.png", G("Mars") },
          } },
          body = {
            { "p", G("In the class view press + New class world, type a name and choose a map:") },
            { "defs", {
                { G("Flat World"), G("A flat grass plain, ideal for free building.") },
                { G("Generic World"), G("A classic world with mountains, forests, rivers and caves.") },
                { G("Countries"), G("Italy, Spain, Germany, Hungary, Poland: real landscapes with rivers, lakes and the main places as teleport points.") },
                { G("Europe"), G("The whole continent, with every border and the capitals.") },
                { G("Moon and Mars"), G("Low gravity, special skies and terrains.") },
            } },
            { "p", G("The world takes a minute or two to start: you can close the window, a new one opens when it is ready. New worlds start safe: no damage or hunger, only peaceful mobs.") },
            { "p", G("Your institute may set a limit of worlds per class: the panel shows how many you have (for example 2 of 3). Delete a world you no longer need to free a place.") },
          } },
        { id = "join", title = G("Entering with the class"),
          body = {
            { "p", G("Each world of the class has Join (you enter alone) and Bring class (you and every online student of the class enter together).") },
            { "p", G("Students can also enter from the portal in the HUB or with their Class worlds tool. They join as students only while you, or someone else of the class staff, are inside; otherwise they visit as spectators and cannot build.") },
            { "tip", G("Enter the world first, or use Bring class: this way nobody ends up as a spectator.") },
            { "h", G("Going back to the HUB") },
            { "p", G("The red Return to HUB button at the top of the class view takes you back. If students are still in the class worlds, choose Me and the students or Only me. Anyone can also type /lobby.") },
          } },
        { id = "live", title = G("Leading the lesson live"),
          body = {
            { "p", G("The live controls at the top left of the class view act on every online student of the class:") },
            { "defs", {
                { G("Freeze"), G("Students cannot move: useful to get their attention while you explain. Click again to unfreeze them.") },
                { G("Bring here"), G("Teleports every online student around you.") },
                { G("Look at me"), G("Turns every student's camera towards you and keeps it there until you press Stop looking.") },
            } },
            { "p", G("Active controls turn orange. In the student list each online student has two icons: teleport yourself to that student, and make only that student look at you.") },
            { "tip", G("Freeze and Bring also work on a single group, from the group cards in Manage people, Groups.") },
          } },
        { id = "rules", title = G("World rules"),
          body = {
            { "p", G("The rules decide how the students play. Open them with Rules on the world card, with the gear of a world, or from World Tools. Every change is saved as soon as you click.") },
            { "defs", {
                { G("Can get hurt"), G("Players lose health from falls, lava and monsters.") },
                { G("Can hit each other (PvP)"), G("Players can hurt each other.") },
                { G("Hunger"), G("Players need to eat.") },
                { G("Students can fly"), G("Students fly with K and move fast with J.") },
                { G("Student creative mode"), G("Unlimited blocks for the students.") },
                { G("Lock the world"), G("Students can only look around, like spectators: useful while you explain.") },
                { G("Mobs and explosions"), G("Animals & mobs spawn, Only peaceful mobs and Explosions break blocks apply after a restart: press Restart now and the players are brought back automatically.") },
            } },
            { "h", G("Arrival point") },
            { "p", G("Stand where the students should appear, look in the right direction and press Use my position. It applies at once, also when someone respawns.") },
            { "p", G("Reset to classroom-safe brings back the safe settings and keeps the arrival point.") },
          } },
        { id = "time", title = G("Time and weather"),
          body = {
            { "p", G("Open Time & weather from the world card or from World Tools. You must be inside the world.") },
            { "defs", {
                { G("Day, Sunset, Night"), G("Sets the time of day at once.") },
                { G("Pause time"), G("Keeps the light as it is now, for example always day. Let time flow starts the clock again.") },
                { G("Clear sky, Rain"), G("Changes the weather.") },
            } },
            { "p", G("Changes apply right away to everyone in the world.") },
          } },
        { id = "manage", title = G("Start, stop, guests and delete"),
          body = {
            { "p", G("The gear of a world, or Settings in World Tools, opens its Settings page:") },
            { "defs", {
                { G("Start world, Stop world"), G("A stopped world keeps everything that was built. Starting it again takes about a minute.") },
                { G("Invite a guest"), G("Lets a player outside the class enter this world, for example a colleague.") },
                { G("Delete world"), G("Removes the world and all its builds forever. Click twice to confirm.") },
            } },
            { "tip", G("At the end of the lesson stop the worlds you are not using: they start again exactly as you left them.") },
          } },
        { id = "minigames", title = G("HUB minigames"),
          body = {
            { "p", G("The pavilions of the HUB have minigames: anyone can play by clicking the launcher of a game.") },
            { "p", G("From the class view press Minigames to start one for the class or one of its groups: choose the game, who plays and the minutes (0 means no limit), then press Start. Only the students who are in the HUB at that moment play.") },
            { "p", G("In solo games each student plays in an arena of their own; in cooperative games the students play together. When every arena is busy, students wait in line for a free one.") },
          } },
    } },

    -- ── World Tools ──────────────────────────────────────────────────────
    { id = "world", title = G("World Tools"), pages = {
        { id = "world_tools", title = G("World Tools"),
          figure = { "images", h = 2.1, images = {
              { "classrooms_bridge_guide_tool_zones.png", G("Zones & missions") },
              { "classrooms_bridge_guide_tool_map.png", G("Map") },
              { "classrooms_bridge_guide_tool_time.png", G("Time & weather") },
              { "classrooms_bridge_guide_tool_rules.png", G("Rules") },
              { "classrooms_bridge_guide_tool_settings.png", G("Settings") },
          } },
          body = {
            { "p", G("Inside a class world you manage, click World Tools in your hotbar (or Tools on the world card of the class panel). The home page shows the world and five tiles:") },
            { "defs", {
                { G("Zones & missions"), G("Protect areas, mark meeting points and give goals to the students.") },
                { G("Map"), G("Waypoints and teleport points for the students.") },
                { G("Time & weather"), G("Day, night, rain.") },
                { G("Rules"), G("Damage, PvP, hunger, mobs.") },
                { G("Settings"), G("Start, stop, guests, delete.") },
            } },
            { "links", { "zones", "map", "missions" } },
          } },
        { id = "zones", title = G("Building zones"),
          figure = { "zone_editor", h = 2.2 },
          body = {
            { "p", G("Zones protect an area of the world, or simply mark a meeting point. Each zone has its name and a coloured border.") },
            { "steps", {
                G("In World Tools open Zones & missions, type the name of the zone and choose who can build inside: Teachers only, Everyone or a group."),
                G("Press Create zone: the editor starts and you can fly through blocks."),
                G("Fly to a corner and use Set point 1, then go to the opposite corner and use Set point 2. The zone covers the whole height."),
                G("If you want, use Set teleport point where players arrive when they are teleported to the zone (otherwise point 1)."),
                G("Use Confirm to save, or Cancel to leave without saving."),
            } },
            { "p", G("Each zone in the list lets you change who can build, teleport yourself, the class or a group into the zone, add a mission and remove the zone. Show in the world draws the borders around you for a few seconds.") },
            { "tip", G("A zone is at most 512 blocks per side, and a world can have up to 40 zones. With no zones, everyone can build everywhere.") },
          } },
        { id = "map", title = G("World map"),
          figure = { "images", h = 2.1, images = {
              { "classrooms_bridge_map_pin.png", G("Waypoint") },
              { "classrooms_bridge_map_tp.png", G("Teleport point") },
              { "classrooms_bridge_map_student.png", G("Student") },
          } },
          body = {
            { "p", G("The world map shows the world from above, with the zones, the players and the points you create. Open it with Map in World Tools; students carry it in their hotbar.") },
            { "steps", {
                G("Click a point on the map (the wheel zooms, the scrollbars move the map)."),
                G("Type a name and press + Waypoint or + Teleport."),
            } },
            { "defs", {
                { G("Waypoint"), G("Students see it in the world as a marker with distance and direction: perfect for a treasure hunt, or to show where to go.") },
                { G("Teleport point"), G("Students can teleport there from their map.") },
            } },
            { "p", G("In the list of places, Go takes you there and Remove deletes a point. Me centres the map on you; Students: shown and hidden shows or hides the players.") },
            { "tip", G("The country maps already have their main places as teleport points.") },
          } },
        { id = "missions", title = G("Missions"),
          figure = { "items", h = 2.0, items = {
              { "mcl_chests:chest", G("Deliver") },
              { "mcl_farming:wheat_item", G("Gather") },
              { "mcl_mobitems:beef", G("Animals") },
              { "mcl_core:brick_block", G("Blocks") },
          } },
          body = {
            { "p", G("A mission gives the students goals to reach together; the progress is shown at the top right of their screen.") },
            { "steps", {
                G("In Zones & missions open the Missions tab and choose where: the whole world, or a zone without a mission (+ Mission on its row)."),
                G("For a whole-world mission choose who plays: the class or a group. A zone mission is played by the group of the zone, or by the class."),
                G("Write a title and a short explanation for the students."),
                G("1 · Goals: choose the type, click a picture, set the amount and press + Add this goal (up to 6 goals)."),
                G("2 · Tools for students: click the items each student receives once, for example a hoe and seeds."),
                G("Press Start mission."),
            } },
            { "defs", {
                { G("Deliver"), G("Bring items into the delivery chest.") },
                { G("Gather"), G("Hold the items, all together, in the inventories.") },
                { G("Animals"), G("Have animals in the zone, or near the chest.") },
                { G("Blocks"), G("Place blocks in the zone, or near the chest.") },
            } },
            { "p", G("When the mission starts you receive the delivery chest: place it inside the zone (anywhere for a whole-world mission). On the mission page you follow the progress and can use Edit goals & tools, Give tools again or delete it. A completed mission can only be deleted.") },
          } },
        { id = "special", title = G("Special missions"),
          figure = { "images", h = 2.1, images = {
              { "classrooms_bridge_fossil_hammer.png", G("Hammer") },
              { "classrooms_bridge_fossil_brush.png", G("Brush") },
              { "classrooms_bridge_fossil_detector.png", G("Detector") },
              { "classrooms_bridge_fossil_trilobite.png", G("Fossil") },
          } },
          body = {
            { "p", G("In the mission editor, the ★ Special missions button at the bottom left lists activities with their own rules. Choose one and adjust its settings: its goals and tools are added by themselves. You can still add normal goals.") },
            { "defs", {
                { G("Find the fossils"), G("Fossils and dinosaur skeletons are hidden underground in the zone. Students get a geologist's hammer, a brush, a field notebook and, if you want, a fossil detector and a miner's helmet. You choose how deep they are, how many there are and how much help to give.") },
                { G("Painting exhibition"), G("Every student gets a frame to paint in pixel art and must hang a number of paintings in the zone. Available on the maps that have the painting mod.") },
            } },
            { "tip", G("Special missions are played in a zone: create the zone first, and let the class or the group build there.") },
          } },
    } },

    -- ── BlockExchange ────────────────────────────────────────────────────
    { id = "bx", title = G("BlockExchange"), pages = {
        { id = "bx_place", title = G("Finding and placing builds"),
          figure = { "bx_steps", h = 2.2 },
          body = {
            { "p", G("The BlockExchange Library, in your hotbar inside class worlds, contains structures shared by teachers and other users: houses, monuments, machines... Open it on the Find & place tab.") },
            { "steps", {
                G("Pick a structure: search by name, filter by tag or institute, and click a row to see its preview."),
                G("Go where it must be built and press Set start here: the structure is built starting from your position."),
                G("Press Check the space to see how big it is and whether it fits, then Build here."),
            } },
            { "p", G("After building, a review bar appears in the hotbar: turn the structure by −90°, 180° or +90°, use Undo to remove it and restore the area, or Save and confirm to keep it.") },
            { "tip", G("Very large structures are built directly, without the review: always check the space first.") },
          } },
        { id = "bx_share", title = G("Sharing your build"),
          body = {
            { "p", G("In the Share a build tab you publish one of your builds in the library, for the other teachers.") },
            { "steps", {
                G("The first time, open your profile on the BlockExchange website, create an access token and sign in with your BlockExchange username and the token."),
                G("Stand on a corner of the build and press Mark corner 1, then on the opposite corner and press Mark corner 2."),
                G("Give it a name (letters, numbers, - _ .), choose its tags if you want, and press Publish to the library."),
            } },
            { "p", G("The progress appears on the screen. Your BlockExchange name and your game name may be different. The token is used only to sign in and is never stored.") },
          } },
    } },

    -- ── Tips and troubleshooting ─────────────────────────────────────────
    { id = "help", title = G("Tips and problems"), pages = {
        { id = "checklist", title = G("Before the lesson"),
          body = {
            { "steps", {
                G("Check that every student has an account and is in the class (Manage people)."),
                G("Create the world in advance: it takes a couple of minutes."),
                G("Set the rules: damage, hunger, flying, creative mode, mobs."),
                G("Enter the world, choose the arrival point and prepare zones, teleport points and missions."),
                G("If materials are needed, fill a chest or choose the tools of the mission."),
                G("When the lesson starts, enter the world and use Bring class."),
            } },
            { "tip", G("Explain the main keys (K, J, I, T) in the first minutes: students who can move easily enjoy the activity much more.") },
          } },
        { id = "problems", title = G("Common problems"),
          body = {
            { "defs", {
                { G("A student entered as a spectator"), G("Nobody of the class staff was inside the world. Enter the world and use Bring class, or ask the student to choose the world again with Class worlds.") },
                { G("A student cannot build"), G("Check the zone (who can build there), Lock the world in the rules and Student creative mode. A message in the chat tells the student why.") },
                { G("A student cannot move"), G("They may be frozen: look at the Freeze control in the class view.") },
                { G("A student is lost"), G("Teleport to them from the student list, or use Bring here.") },
                { G("A world is missing from the running ones"), G("It may be stopped: start it from its gear.") },
                { G("A world says restart needed"), G("Mobs and explosions need a restart: press Restart now, the players come back by themselves.") },
                { G("A tool disappeared from the hotbar"), G("Wait a second: the tools come back by themselves. Otherwise leave the world and enter again.") },
                { G("A student forgot the password"), G("Change it with the padlock in Manage people, Students.") },
            } },
          } },
        { id = "ideas", title = G("Lesson ideas"),
          body = {
            { "defs", {
                { G("Farm challenge"), G("A zone for each group and the mission Deliver 32 wheat, with a hoe, seeds and a water bucket as tools.") },
                { G("Treasure hunt"), G("Waypoints on the map, and at each place a sign with a question.") },
                { G("Build a monument"), G("Each group builds a famous monument in its zone; at the end everyone visits them through teleport points.") },
                { G("Geography trip"), G("On a country map the students fly to the teleport points and write in a book what they see.") },
                { G("Little palaeontologists"), G("The special mission Find the fossils, then each student describes a fossil from the field notebook.") },
                { G("Pixel art gallery"), G("The special mission Painting exhibition, on a topic of the lesson.") },
            } },
          } },
    } },
}
