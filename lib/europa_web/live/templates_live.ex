defmodule EuropaWeb.TemplatesLive do
  # TODO: write tests
  # coveralls-ignore-start
  use EuropaWeb, :live_view
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet
  alias Europa.Server.Planet.Templates
  alias Europa.Server.Planet.Tiles
  alias Europa.Server.Player
  alias Europa.Server.Characters

  import EuropaWeb.GameCompotents

  @snow Tiles.tile(:snow).atom_value

  @impl true
  def mount(_params, _session, socket) do
    empty_template = Templates.build_empty_template() |> Jason.encode!(pretty: true)

    {:ok, characters_pid} = Characters.start_link()
    {:ok, current_character} = Characters.pick_main(characters_pid)

    planet = Planet.new(year: 2153, characters_pid: characters_pid, player_fraction: :neutral)
    player = Player.new(current_character)

    socket =
      socket
      |> assign(
        json: empty_template,
        planet: planet,
        player: player,
        template: nil
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("change_template_json", %{"value" => new_json}, socket) do
    {:noreply, assign(socket, json: new_json)}
  end

  def handle_event("render_template", _params, socket) do
    socket =
      case Jason.decode(socket.assigns.json, keys: :atoms) do
        {:ok, decoded_json} ->
          do_render_template(decoded_json, socket)

        _ ->
          put_flash(socket, :error, "Invalid json")
      end

    {:noreply, socket}
  end

  def handle_event(_, _, socket) do
    {:noreply, socket}
  end

  defp do_render_template(raw_template, socket) do
    case Templates.Template.from_map(raw_template) do
      {:ok, template} ->
        final_template = prepare_template(socket.assigns.planet, template)

        assign(socket,
          template: final_template,
          template_width: template_width(template),
          template_height: template_height(template)
        )

      {:error, reason} ->
        put_flash(socket, :error, reason)
    end
  end

  defp prepare_template(%Planet{} = planet, %Templates.Template{} = template) do
    determined_template = Templates.Template.determine(template)

    Enum.with_index(determined_template, fn row, x ->
      Enum.with_index(row, fn tile, y ->
        {{x, y}, Planet.prepare_predefined_tile(tile, {x, y}, planet, @snow)}
      end)
    end)
  end

  defp template_width(template) do
    template.content |> Enum.map(&length/1) |> Enum.max()
  end

  defp template_height(template) do
    length(template.content)
  end

  # coveralls-ignore-stop
end
