defmodule EuropaWeb.AdminPanelHTML do
  use EuropaWeb, :html

  import EuropaWeb.AdminPanelComponents

  embed_templates("admin_panel_html/*")
end
