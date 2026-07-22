defmodule EuropaWeb.GameHTML do
  use EuropaWeb, :html

  import EuropaWeb.GameCompotents

  embed_templates("game_html/*")
end
