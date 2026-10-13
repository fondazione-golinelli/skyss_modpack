local S = core.get_translator("serverguide")
local FS = function(...) return core.formspec_escape(S(...)) end

local function get_formspec()
  local formspec = {
  "formspec_version[4]",
  "size[12,17.4]",
  "position[0.5,0.47]",
  "no_prepend[]",
  "bgcolor[;true]",
  "background[0,0;12,17.4;serverguide_values_bg.png]",
  "hypertext[1.87,1;8.27,1.47;title_txt;<global size=20 halign=center valign=middle font=mono><style color=#302c2e><b>" .. FS("BIOPHILIA VALUES") .. "</b>]",
  "hypertext[4.8,3.07;5,0.93;head1_txt;<global size=13 font=mono halign=center valign=middle color=#302c2e><b>" .. FS("CONNECTION") .. "</b>]",
  "hypertext[3.93,4.07;6.73,1.87;body1_txt;<global size=12 font=mono valign=middle color=#302c2e>" .. FS("Biophilia reminds us that people feel better when they notice plants, animals, weather, water, soil, and living systems around them.") .. "]",
  "hypertext[2.27,6.4;5,0.93;head2_txt;<global size=13 font=mono halign=center valign=middle color=#302c2e><b>" .. FS("CURIOSITY") .. "</b>]",
  "hypertext[1.4,7.4;6.73,1.87;body2_txt;<global size=12 font=mono valign=middle color=#302c2e>" .. FS("Explore slowly, ask questions, and observe details. Every landscape can teach something about how life adapts and cooperates.") .. "]",
  "hypertext[4.8,9.73;5,0.93;head3_txt;<global size=13 font=mono halign=center valign=middle color=#302c2e><b>" .. FS("CARE") .. "</b>]",
  "hypertext[3.93,10.73;6.73,1.87;body3_txt;<global size=12 font=mono valign=middle color=#302c2e>" .. FS("Respect shared spaces and the living world. Build, play, and learn in ways that protect habitats and help others enjoy them.") .. "]",
  "hypertext[2.27,13.07;5,0.93;head4_txt;<global size=13 font=mono halign=center valign=middle color=#302c2e><b>" .. FS("BALANCE") .. "</b>]",
  "hypertext[1.4,14.07;6.73,1.87;body4_txt;<global size=12 font=mono valign=middle color=#302c2e>" .. FS("Human creativity and nature can grow together. Good choices leave room for beauty, biodiversity, and future players.") .. "]",
  "image_button_exit[12.3,0.39;0.65,0.65;arenalib_infobox_quit.png;quit;;true;false;]"
  }

  return table.concat(formspec, "")
end



function serverguide.get_values_formspec(p_name)
  core.show_formspec(p_name, "serverguide:values", get_formspec())
end
