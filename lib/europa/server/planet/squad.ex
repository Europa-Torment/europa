defmodule Europa.Server.Planet.Squad do
  use TypedStruct
  use Gettext, backend: Europa.Gettext

  alias Europa.Server.Planet.Squad.Member
  alias Europa.Server.Planet
  alias Europa.Server.Action
  alias Europa.Server.Npc
  alias Europa.Server.Enemy
  alias Europa.Server.Characters.Profession
  alias Europa.Server.Loot
  alias Europa.Tools.Types
  alias Europa.Tools.NumberHelpers

  import Europa.Tools.Randomizer
  import Europa.Tools.Conf

  @base_heal fetch_config!([:game_params, :squad, :base_heal])

  @member_remove_reasons [:died, :left, :fired]

  @ammo_per_member 20
  @supplies_per_member 20
  @other_resources_per_member 30

  @critical_moves_count_with_low_resources 500

  @low_resources_event_interval_seconds 60 * 3

  @type member_remove_reason :: unquote(Types.one_of(@member_remove_reasons))

  @type members :: %{optional(Npc.uuid()) => Member.t()}

  @type event ::
          {:declined, Npc.t()}
          | {:recruited, Member.t()}
          | {:member_died, Member.t()}
          | {:member_left_squad, Member.t()}
          | :low_resources

  @attack_modes [
    {:enemy, gettext("Monsters")},
    {:npc, gettext("Other survivors")},
    {:any, gettext("Everyone")},
    {:nodody, gettext("Nobody")}
  ]
  @allowed_attack_modes Enum.map(@attack_modes, fn {k, _v} -> k end)
  @type attack_mode :: unquote(Types.one_of(@allowed_attack_modes))

  @professions Profession.professions()

  defmodule Member do
    typedstruct enforce: true do
      field :coord, Planet.coord()
      field :npc, Npc.t()
    end

    @spec new(Npc.t(), Planet.coord()) :: t()
    def new(%Npc{} = npc, {_x, _y} = coord) do
      %__MODULE__{
        npc: npc,
        coord: coord
      }
    end
  end

  defmodule Resources do
    typedstruct enforce: true do
      field :supplies, non_neg_integer()
      field :ammo, non_neg_integer()
      field :other, non_neg_integer()
    end

    @spec new() :: t()
    def new do
      %__MODULE__{
        supplies: 0,
        ammo: 0,
        other: 0
      }
    end

    @spec add(t(), keyword()) :: t()
    def add(%__MODULE__{} = resources, opts) when is_list(opts) do
      keys = Map.keys(resources)

      changes =
        opts
        |> Keyword.take(keys)
        |> Enum.filter(fn {_k, v} -> is_integer(v) end)
        |> Enum.map(fn {k, v} ->
          {k, max(Map.fetch!(resources, k) + v, 0)}
        end)

      struct!(resources, changes)
    end
  end

  defmodule DeclinedNpc do
    import Europa.Tools.Conf

    @moves_before_re_invite fetch_config!([:game_params, :squad, :moves_before_re_invite])

    typedstruct enforce: true do
      field :uuid, Npc.uuid()
      field :rest_moves, non_neg_integer()
    end

    @spec new(Npc.t()) :: t()
    def new(%Npc{uuid: uuid}) do
      %__MODULE__{
        uuid: uuid,
        rest_moves: @moves_before_re_invite
      }
    end

    @spec decrease_rest_moves(t()) :: t()
    def decrease_rest_moves(%__MODULE__{rest_moves: rest_moves} = declined_npc) do
      struct!(declined_npc, rest_moves: max(rest_moves - 1, 0))
    end
  end

  typedstruct enforce: true do
    field :members, members()
    field :resources, Resources.t()
    field :loot_types, list(Loot.item_type())
    field :attack_mode, attack_mode(), default: :enemy
    field :assigned_coords, list(Planet.coord())
    field :events, list(event())
    field :declined_npcs, list(DeclinedNpc.t())
    field :moves_with_low_resources, non_neg_integer(), default: 0
    field :low_resources_event_at, non_neg_integer(), default: 0
  end

  @spec new() :: t()
  def new do
    %__MODULE__{
      members: %{},
      resources: Resources.new(),
      loot_types: [],
      assigned_coords: [],
      events: [],
      declined_npcs: [],
      moves_with_low_resources: 0,
      low_resources_event_at: now_seconds()
    }
  end

  @spec recruit_member(t(), Npc.t(), Planet.coord()) :: {:ok, t()} | {:error, :already_in_squad}
  def recruit_member(%__MODULE__{} = squad, %Npc{} = npc, {_x, _y} = coord) do
    if member?(squad, npc) do
      {:error, :already_in_squad}
    else
      do_recruit_member(squad, npc, coord)
    end
  end

  @spec update_member(t(), Npc.t(), Planet.coord()) :: {:ok, t()} | {:error, :not_member}
  def update_member(%__MODULE__{} = squad, %Npc{} = npc, {_x, _y} = coord) do
    if member?(squad, npc) do
      member = Member.new(npc, coord)
      {:ok, struct!(squad, members: Map.put(squad.members, npc.uuid, member))}
    else
      {:error, :not_member}
    end
  end

  @spec remove_member(t(), Npc.t() | Npc.uuid(), member_remove_reason()) :: {:ok, t()} | {:error, :not_member}
  def remove_member(%__MODULE__{} = squad, %Npc{} = npc, reason) when reason in @member_remove_reasons do
    case get_member(squad, npc.uuid) do
      {:ok, member} ->
        events =
          case reason do
            :died -> [{:member_died, member}]
            :left -> [{:member_left_squad, member}]
            _ -> []
          end

        declined_npc = DeclinedNpc.new(npc)

        updated_squad =
          squad
          |> struct!(members: Map.delete(squad.members, npc.uuid), declined_npcs: [declined_npc | squad.declined_npcs])
          |> maybe_remove_npc_assigned_coord(npc)
          |> add_events(events)

        {:ok, updated_squad}

      error ->
        error
    end
  end

  def remove_member(%__MODULE__{} = squad, npc_uuid, reason) when is_binary(npc_uuid) do
    case Map.get(squad.members, npc_uuid) do
      nil -> {:error, :not_member}
      member -> remove_member(squad, member.npc, reason)
    end
  end

  @spec member_coords(t()) :: list(Planet.coord())
  def member_coords(%__MODULE__{members: members}) do
    members
    |> Map.values()
    |> Enum.map(& &1.coord)
  end

  @spec member?(t(), Npc.t()) :: boolean()
  def member?(%__MODULE__{} = squad, %Npc{} = npc) do
    Map.has_key?(squad.members, npc.uuid)
  end

  @spec take_items(t(), list(Loot.Item.item())) :: {:ok, t()}
  def take_items(%__MODULE__{} = squad, items) when is_list(items) do
    updated_resources =
      Enum.reduce(items, squad.resources, fn item, resources ->
        case item do
          %Loot.Weapon{rounds_loaded: count} -> Resources.add(resources, ammo: count + 2)
          %Loot.Weapon.Ammo{count: count} -> Resources.add(resources, ammo: count)
          %Loot.Supply{count: count} -> Resources.add(resources, supplies: count)
          %{count: count} -> Resources.add(resources, other: count)
          _ -> Resources.add(resources, other: 1)
        end
      end)

    {:ok, struct!(squad, resources: updated_resources)}
  end

  @spec set_loot_types(t(), list(Loot.item_type())) :: {:ok, t()} | {:error, :invalid_loot_types}
  def set_loot_types(%__MODULE__{} = squad, loot_types) when is_list(loot_types) do
    allowed_loot_types = Loot.allowed_item_types() |> Enum.map(fn {type, _readable_type} -> type end)

    if Enum.all?(loot_types, &(&1 in allowed_loot_types)) do
      {:ok, struct!(squad, loot_types: loot_types)}
    else
      {:error, :invalid_loot_types}
    end
  end

  @spec set_attack_mode(t(), attack_mode()) :: {:ok, t()}
  def set_attack_mode(%__MODULE__{} = squad, attack_mode) when attack_mode in @allowed_attack_modes do
    {:ok, struct!(squad, attack_mode: attack_mode)}
  end

  @spec can_attack?(t(), Npc.t() | Enemy.t()) :: boolean()
  def can_attack?(%__MODULE__{attack_mode: attack_mode}, %Enemy{}) when attack_mode in [:enemy, :any] do
    true
  end

  def can_attack?(%__MODULE__{attack_mode: attack_mode} = squad, %Npc{} = npc) when attack_mode in [:npc, :any] do
    not member?(squad, npc)
  end

  def can_attack?(_, _) do
    false
  end

  @spec attack_modes() :: list({attack_mode(), String.t()})
  def attack_modes do
    @attack_modes
  end

  @spec assign_coord(t(), Planet.coord()) :: t()
  def assign_coord(%__MODULE__{} = squad, {_x, _y} = coord) do
    if coord in squad.assigned_coords do
      squad
    else
      struct!(squad, assigned_coords: [coord | squad.assigned_coords])
    end
  end

  @spec remove_assigned_coord(t(), Planet.coord()) :: t()
  def remove_assigned_coord(%__MODULE__{} = squad, {_x, _y} = coord) do
    if coord in squad.assigned_coords do
      struct!(squad, assigned_coords: squad.assigned_coords -- [coord])
    else
      squad
    end
  end

  @spec register_shoot(t()) :: t()
  def register_shoot(%__MODULE__{} = squad) do
    updated_resources = Resources.add(squad.resources, ammo: -1)
    struct!(squad, resources: updated_resources)
  end

  @spec resource_satisfaction(t(), resource_name :: atom()) :: non_neg_integer()
  def resource_satisfaction(%__MODULE__{} = squad, resource_name) do
    resource = Map.fetch!(squad.resources, resource_name)
    members_count = Enum.count(squad.members)

    if members_count == 0 do
      100
    else
      case resource_name do
        :ammo -> round(resource / (members_count * @ammo_per_member) * 100)
        :supplies -> round(resource / (members_count * @supplies_per_member) * 100)
        :other -> round(resource / (members_count * @other_resources_per_member) * 100)
      end
    end
  end

  @spec satisfaction(t()) :: non_neg_integer()
  def satisfaction(%__MODULE__{} = squad) do
    [:ammo, :supplies, :other]
    |> Enum.map(&resource_satisfaction(squad, &1))
    |> NumberHelpers.harmonic_mean()
  end

  @spec tick(t()) :: {:ok, t(), list(Action.t())}
  def tick(%__MODULE__{} = squad) do
    ticks = [
      fn squad -> use_resources(squad) end,
      fn squad -> check_low_resources(squad) end,
      fn squad -> maybe_remove_member(squad) end,
      fn squad -> progress_declined_npcs(squad) end
    ]

    {updated_squad, actions} =
      Enum.reduce(ticks, {squad, []}, fn tick, {squad, actions} ->
        {updated_squad, new_actions} = tick.(squad)
        {updated_squad, actions ++ new_actions}
      end)

    {:ok, updated_squad, actions}
  end

  @spec use_supply(t()) :: {:ok, t(), health :: pos_integer()} | {:error, :no_supplies}
  def use_supply(%__MODULE__{} = squad) do
    if squad.resources.supplies >= 1 do
      updated_resources = Resources.add(squad.resources, supplies: -1)
      {:ok, struct!(squad, resources: updated_resources), heal_amount(squad.members)}
    else
      {:error, :no_supplies}
    end
  end

  @spec remove_last_event(t()) :: {:ok, t(), event()} | {:error, :no_events}
  def remove_last_event(%__MODULE__{events: [event | rest]} = squad) do
    {:ok, struct!(squad, events: rest), event}
  end

  def remove_last_event(_), do: {:error, :no_events}

  @spec declined?(t(), Npc.t()) :: boolean()
  def declined?(%__MODULE__{} = squad, %Npc{} = npc) do
    Enum.any?(squad.declined_npcs, fn declined_npc -> declined_npc.uuid == npc.uuid end)
  end

  defp use_resources(%__MODULE__{} = squad) do
    members_count = Enum.count(squad.members)

    if members_count > 0 && m_to_n?(1, 30) do
      amount = used_resources_amount(squad.members)
      updated_resources = Resources.add(squad.resources, other: -amount)

      {struct!(squad, resources: updated_resources), _actions = []}
    else
      {squad, _actions = []}
    end
  end

  defp used_resources_amount(members) do
    members_count = Enum.count(members)

    if members_count > 0 && m_to_n?(1, 5) do
      economed_resources =
        members
        |> Map.values()
        |> Enum.map(fn %Member{npc: npc} ->
          profession = Map.fetch!(@professions, npc.character.profession)
          Enum.filter(profession.properties, &(&1.id == :resources_economy))
        end)
        |> List.flatten()
        |> Enum.sum_by(& &1.level)

      max(members_count - economed_resources, 0)
    else
      members_count
    end
  end

  defp heal_amount(members) do
    additional_heal =
      members
      |> Map.values()
      |> Enum.map(fn %Member{npc: npc} ->
        profession = Map.fetch!(@professions, npc.character.profession)
        Enum.filter(profession.properties, &(&1.id == :heal))
      end)
      |> List.flatten()
      |> Enum.sum_by(&(&1.level + 5))

    @base_heal + additional_heal
  end

  defp check_low_resources(%__MODULE__{members: members} = squad) when map_size(members) > 0 do
    other_resources_count = squad.resources.other

    now_time = now_seconds()
    can_add_event? = now_time - squad.low_resources_event_at >= @low_resources_event_interval_seconds

    cond do
      other_resources_count == 0 && can_add_event? ->
        updated_squad =
          squad
          |> add_events([:low_resources])
          |> increase_moves_with_low_resources()
          |> struct!(low_resources_event_at: now_time)

        {updated_squad, []}

      other_resources_count == 0 ->
        {increase_moves_with_low_resources(squad), []}

      true ->
        {struct!(squad, moves_with_low_resources: 0), []}
    end
  end

  defp check_low_resources(%__MODULE__{} = squad), do: {squad, []}

  defp maybe_remove_member(%__MODULE__{members: members} = squad) when map_size(members) > 0 do
    if squad.moves_with_low_resources >= @critical_moves_count_with_low_resources && m_to_n?(1, 30) do
      {_uuid, member} = Enum.random(members)
      {:ok, updated_squad} = remove_member(squad, member.npc, :left)

      updated_squad =
        updated_squad
        |> add_events([{:member_left_squad, member}])
        |> struct!(moves_with_low_resources: div(@critical_moves_count_with_low_resources, 2))

      {updated_squad, []}
    else
      {squad, []}
    end
  end

  defp maybe_remove_member(%__MODULE__{} = squad), do: {squad, []}

  defp progress_declined_npcs(%__MODULE__{declined_npcs: []} = squad), do: {squad, []}

  defp progress_declined_npcs(%__MODULE__{declined_npcs: declined_npcs} = squad) do
    updated_declined_npcs =
      declined_npcs
      |> Enum.map(fn
        %DeclinedNpc{rest_moves: 0} -> nil
        declined_npc -> DeclinedNpc.decrease_rest_moves(declined_npc)
      end)
      |> Enum.filter(&(not is_nil(&1)))

    {struct!(squad, declined_npcs: updated_declined_npcs), []}
  end

  defp increase_moves_with_low_resources(%__MODULE__{} = squad) do
    struct!(squad, moves_with_low_resources: squad.moves_with_low_resources + 1)
  end

  defp maybe_remove_npc_assigned_coord(%__MODULE__{} = squad, %Npc{target: {_x, _y} = coord}) do
    remove_assigned_coord(squad, coord)
  end

  defp maybe_remove_npc_assigned_coord(%__MODULE__{} = squad, _npc) do
    squad
  end

  defp do_recruit_member(%__MODULE__{} = squad, %Npc{} = npc, {_x, _y} = coord) do
    cond do
      declined?(squad, npc) ->
        {:ok, squad}

      want_recruit?(squad) ->
        member = Member.new(npc, coord)
        {:ok, struct!(squad, members: Map.put(squad.members, npc.uuid, member)) |> add_events([{:recruited, member}])}

      true ->
        declined_npc = DeclinedNpc.new(npc)
        {:ok, struct!(squad, declined_npcs: [declined_npc | squad.declined_npcs]) |> add_events([{:declined, npc}])}
    end
  end

  defp want_recruit?(%__MODULE__{} = squad) do
    satisfaction = satisfaction(squad)
    m_to_n?(satisfaction, 100)
  end

  defp add_events(%__MODULE__{} = squad, []), do: squad

  defp add_events(%__MODULE__{} = squad, events) when is_list(events) do
    struct!(squad, events: Enum.uniq(squad.events ++ events))
  end

  def get_member(%__MODULE__{} = squad, uuid) do
    case Map.get(squad.members, uuid) do
      nil -> {:error, :not_member}
      member -> {:ok, member}
    end
  end

  defp now_seconds, do: System.os_time(:second)
end
