defmodule EuropaWeb.UserHTML do
  @moduledoc """
  This module contains pages rendered by UserController.

  See the `user_html` directory for all templates available.
  """
  use EuropaWeb, :html

  embed_templates("user_html/*")
end
