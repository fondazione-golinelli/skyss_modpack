local S = core.get_translator("serverguide")
local FS = function(...) return core.formspec_escape(S(...)) end

local function get_formspec() end



function serverguide.get_values_formspec(p_name)
  core.show_formspec(p_name, "serverguide:values", get_formspec())
end





----------------------------------------------
---------------FUNZIONI LOCALI----------------
----------------------------------------------

function get_formspec()
  local formspec = {
  "formspec_version[4]",
  "size[12,17.3]",
  "position[0.5,0.47]",
  "no_prepend[]",
  "bgcolor[;true]",
  "background[0,0;12,17.3;aesguide_values.png]",
  "hypertext[1,0.9;10,2;weap_txt;<global size=26 halign=center valign=middle font=mono><style color=#302c2e><b>" .. FS("BIOPHILIA VALUES") .. "</b>]",
  "hypertext[3.5,2.98;3.9,1.2;pname_txt;<global size=13 font=mono halign=center valign=middle color=#302c2e><b>" .. FS("CONNECTION") .. "</b>]",
  "hypertext[3.5,3.98;7.1,2;pname_txt;<global size=12 font=mono valign=middle color=#302c2e>" .. FS("Biophilia reminds us that people feel better when they notice plants, animals, weather, water, soil, and living systems around them.") .. "</b>]",
  "hypertext[4.15,6.86;3.9,1.2;pname_txt;<global size=13 font=mono halign=center valign=middle color=#302c2e><b>" .. FS("CURIOSITY") .. "</b>]",
  "hypertext[1.35,7.9;7.1,1.2;pname_txt;<global size=12 font=mono valign=middle color=#302c2e>" .. FS("Explore slowly, ask questions, and observe details. Every landscape can teach something about how life adapts and cooperates.") .. "]",
  "hypertext[3.64,10.06;3.9,1.2;pname_txt;<global size=13 font=mono halign=center valign=middle color=#302c2e><b>" .. FS("CARE") .. "</b>]",
  "hypertext[3.5,11.12;7.1,1.2;pname_txt;<global size=12 font=mono valign=middle color=#302c2e>" .. FS("Respect shared spaces and the living world. Build, play, and learn in ways that protect habitats and help others enjoy them.") .. "]",
  "hypertext[4.15,13.3;3.9,1.2;pname_txt;<global size=13 font=mono halign=center valign=middle color=#302c2e><b>" .. FS("BALANCE") .. "</b>]",
  "hypertext[1.35,14.36;7.1,1.2;pname_txt;<global size=12 font=mono valign=middle color=#302c2e>" .. FS("Human creativity and nature can grow together. Good choices leave room for beauty, biodiversity, and future players.") .. "]",
  "image_button_exit[12.3,0.39;0.65,0.65;arenalib_infobox_quit.png;quit;;true;false;]"
  }

  return table.concat(formspec, "")
end
