defmodule Europa.Server.Planet.SquadTest do
  use Europa.DataCase, async: true
  use ExUnitProperties

  alias Europa.Server.Planet.Squad
  alias Europa.Server.Npc

  import Europa.Tools.Conf

  @base_heal fetch_config!([:game_params, :squad, :base_heal])

  describe "new/0" do
    test "build Squad struct" do
      assert %Squad{} = Squad.new()
    end
  end

  describe "recruit_member/3" do
    test "adds new member" do
      squad = build(:squad)

      npc = build(:npc)
      npc_uuid = npc.uuid
      npc_coord = {1, 2}

      assert {:ok, %Squad{members: %{^npc_uuid => %Squad.Member{npc: ^npc, coord: ^npc_coord}}}} =
               Squad.recruit_member(squad, npc, npc_coord)
    end

    test "returns error when member is already in squad" do
      squad = build(:squad)

      npc = build(:npc)
      npc_uuid = npc.uuid
      npc_coord = {1, 2}

      assert {:ok, %Squad{members: %{^npc_uuid => %Squad.Member{npc: ^npc, coord: ^npc_coord}}} = updated_squad} =
               Squad.recruit_member(squad, npc, npc_coord)

      assert {:error, :already_in_squad} = Squad.recruit_member(updated_squad, npc, npc_coord)
    end

    test "returns error when not enough resources to add new members" do
      squad = build(:squad)

      [npc, npc2] = build_list(2, :npc)
      npc_coord = {1, 2}
      npc_coord2 = {1, 2}

      assert {:ok, squad} = Squad.recruit_member(squad, npc, npc_coord)
      assert {:ok, updated_squad} = Squad.recruit_member(squad, npc2, npc_coord2)

      assert updated_squad.members == squad.members
      assert {:declined, npc2} in updated_squad.events
    end
  end

  describe "update_member/3" do
    test "updates member" do
      coord = {123, 456}

      member = build(:squad_member)
      npc_uuid = member.npc.uuid
      updated_npc = Npc.take_damage(member.npc, 1)

      squad = build(:squad, members: %{npc_uuid => member})

      assert {:ok, %Squad{members: %{^npc_uuid => %Squad.Member{npc: ^updated_npc, coord: ^coord}}}} =
               Squad.update_member(squad, updated_npc, coord)
    end

    test "returns error when npc is not squad member" do
      squad = build(:squad)
      npc = build(:npc)
      coord = {456, 732}

      assert {:error, :not_member} = Squad.update_member(squad, npc, coord)
    end
  end

  describe "remove_member/3" do
    test "removes member (died)" do
      member = build(:squad_member)
      npc_uuid = member.npc.uuid

      squad = build(:squad, members: %{npc_uuid => member})

      assert {:ok, %Squad{members: updated_members, events: [{:member_died, ^member}]}} =
               Squad.remove_member(squad, member.npc, :died)

      assert updated_members == %{}
    end

    test "removes member (left)" do
      member = build(:squad_member)
      npc_uuid = member.npc.uuid

      squad = build(:squad, members: %{npc_uuid => member})

      assert {:ok,
              %Squad{
                members: updated_members,
                declined_npcs: [%Squad.DeclinedNpc{uuid: ^npc_uuid}],
                events: [{:member_left_squad, ^member}]
              }} =
               Squad.remove_member(squad, member.npc, :left)

      assert updated_members == %{}
    end

    test "returns error when npc is not squad member" do
      squad = build(:squad)
      npc = build(:npc)

      assert {:error, :not_member} = Squad.remove_member(squad, npc, :died)
    end
  end

  describe "member_coords/1" do
    test "reuturns list of squad member coords" do
      [member, member2] = build_list(2, :squad_member)

      squad = build(:squad, members: %{member.npc.uuid => member, member2.npc.uuid => member2})
      assert Squad.member_coords(squad) |> Enum.sort() == Enum.sort([member2.coord, member.coord])
    end
  end

  describe "member?/2" do
    test "checks if npc is squad member" do
      [member, member2] = build_list(2, :squad_member)
      npc_uuid = member.npc.uuid

      squad = build(:squad, members: %{npc_uuid => member})
      assert Squad.member?(squad, member.npc) == true
      assert Squad.member?(squad, member2.npc) == false
    end
  end

  describe "take_items/2" do
    test "adds squad resources" do
      squad = build(:squad, resources: build(:squad_resources, ammo: 1, supplies: 2, other: 3))

      ammo = build(:ammo, count: 10)
      weapon = build(:weapon, rounds_loaded: 5)
      supply = build(:supply, count: 20)
      implant = build(:implant)
      boots = build(:boots)
      resource = build(:resource, count: 50)

      assert {:ok, updated_squad} = Squad.take_items(squad, [ammo, weapon, supply, implant, boots, resource])

      assert updated_squad.resources.ammo == squad.resources.ammo + ammo.count + weapon.rounds_loaded
      assert updated_squad.resources.supplies == squad.resources.supplies + supply.count
      assert updated_squad.resources.other == squad.resources.other + resource.count + 2
    end
  end

  describe "set_loot_types" do
    test "sets loot types" do
      squad = build(:squad, loot_types: [:ammo])
      loot_types = [:weapon, :boots]
      assert {:ok, %Squad{loot_types: ^loot_types}} = Squad.set_loot_types(squad, loot_types)
    end

    test "returns invalid_loot_types error" do
      squad = build(:squad, loot_types: [:ammo])
      assert {:error, :invalid_loot_types} = Squad.set_loot_types(squad, [:fake])
    end
  end

  describe "assign_coord/2" do
    test "saves given coord" do
      coord = {1, 2}
      coord2 = {1, 3}

      squad = build(:squad, assigned_coords: [coord])
      assert %Squad{assigned_coords: [^coord2, ^coord]} = Squad.assign_coord(squad, coord2)
    end

    test "doesnt duplicates coords" do
      coord = {1, 2}

      squad = build(:squad, assigned_coords: [coord])
      assert %Squad{assigned_coords: [^coord]} = Squad.assign_coord(squad, coord)
    end
  end

  describe "remove_assigned_coord/2" do
    test "removes assigned coord" do
      coord = {1, 2}

      squad = build(:squad, assigned_coords: [coord])
      assert %Squad{assigned_coords: []} = Squad.remove_assigned_coord(squad, coord)
    end

    test "does nothing when coord not assigned" do
      coord = {1, 2}
      coord2 = {2, 4}

      squad = build(:squad, assigned_coords: [coord])
      assert %Squad{assigned_coords: [^coord]} = Squad.remove_assigned_coord(squad, coord2)
    end
  end

  describe "register_shoot/1" do
    test "decreases ammo count" do
      squad = build(:squad, resources: build(:squad_resources, ammo: 10))
      assert %Squad{resources: %Squad.Resources{ammo: 9}} = Squad.register_shoot(squad)
    end
  end

  describe "resource_satisfaction/2" do
    test "returns ammo satisfaction" do
      member = build(:squad_member)

      squad = build(:squad, members: %{}, resources: build(:squad_resources, ammo: 0))
      squad2 = build(:squad, members: %{member.npc.uuid => member}, resources: build(:squad_resources, ammo: 0))
      squad3 = build(:squad, members: %{member.npc.uuid => member}, resources: build(:squad_resources, ammo: 10))

      assert Squad.resource_satisfaction(squad, :ammo) == 100
      assert Squad.resource_satisfaction(squad2, :ammo) == 0
      assert Squad.resource_satisfaction(squad3, :ammo) == 50
    end

    test "returns supplies satisfaction" do
      member = build(:squad_member)

      squad = build(:squad, members: %{}, resources: build(:squad_resources, supplies: 0))
      squad2 = build(:squad, members: %{member.npc.uuid => member}, resources: build(:squad_resources, supplies: 0))
      squad3 = build(:squad, members: %{member.npc.uuid => member}, resources: build(:squad_resources, supplies: 10))

      assert Squad.resource_satisfaction(squad, :supplies) == 100
      assert Squad.resource_satisfaction(squad2, :supplies) == 0
      assert Squad.resource_satisfaction(squad3, :supplies) == 50
    end

    test "returns other resources satisfaction" do
      member = build(:squad_member)

      squad = build(:squad, members: %{}, resources: build(:squad_resources, other: 0))
      squad2 = build(:squad, members: %{member.npc.uuid => member}, resources: build(:squad_resources, other: 0))
      squad3 = build(:squad, members: %{member.npc.uuid => member}, resources: build(:squad_resources, other: 15))

      assert Squad.resource_satisfaction(squad, :other) == 100
      assert Squad.resource_satisfaction(squad2, :other) == 0
      assert Squad.resource_satisfaction(squad3, :other) == 50
    end
  end

  describe "satisfaction/1" do
    test "returns squad resources satisfaction" do
      [member, member2] = build_list(2, :squad_member)

      resources = build(:squad_resources, ammo: 100, supplies: 200, other: 300)

      squad = build(:squad, members: %{}, resources: resources)
      squad2 = build(:squad, members: %{member.npc.uuid => member}, resources: resources)
      squad3 = build(:squad, members: %{member.npc.uuid => member, member2.npc.uuid => member2}, resources: resources)

      assert Squad.satisfaction(squad) == 100
      assert Squad.satisfaction(squad2) == 750
      assert Squad.satisfaction(squad3) == 375
    end
  end

  describe "tick/1" do
    test "increases moves_with_low_resources (initial)" do
      member = build(:squad_member)

      resources = build(:squad_resources, ammo: 100, supplies: 200, other: 0)
      squad = build(:squad, members: %{member.npc.uuid => member}, resources: resources, moves_with_low_resources: 0)

      assert {:ok, %Squad{moves_with_low_resources: 1, events: [:low_resources]}, []} = Squad.tick(squad)
    end

    test "increases moves_with_low_resources" do
      member = build(:squad_member)

      resources = build(:squad_resources, ammo: 100, supplies: 200, other: 0)
      squad = build(:squad, members: %{member.npc.uuid => member}, resources: resources, moves_with_low_resources: 10)

      assert {:ok, %Squad{moves_with_low_resources: 11, events: [:low_resources]}, []} = Squad.tick(squad)
    end

    test "skips moves_with_low_resources" do
      member = build(:squad_member)

      resources = build(:squad_resources, ammo: 100, supplies: 200, other: 10)
      squad = build(:squad, members: %{member.npc.uuid => member}, resources: resources, moves_with_low_resources: 10)

      assert {:ok, %Squad{moves_with_low_resources: 0, events: []}, []} = Squad.tick(squad)
    end

    test "progress declined_npcs" do
      declined_npc = build(:squad_declined_npc, rest_moves: 100)
      declined_npc2 = build(:squad_declined_npc, rest_moves: 0)

      declined_npc_uuid = declined_npc.uuid
      squad = build(:squad, declined_npcs: [declined_npc, declined_npc2])

      assert {:ok, %Squad{declined_npcs: [%Squad.DeclinedNpc{uuid: ^declined_npc_uuid, rest_moves: 99}]}, []} =
               Squad.tick(squad)
    end

    property "decreases other resources count" do
      members_count = 2
      [member, member2] = build_list(members_count, :squad_member)

      resources = build(:squad_resources, ammo: 100, supplies: 200, other: 300)
      squad = build(:squad, members: %{member.npc.uuid => member, member2.npc.uuid => member2}, resources: resources)

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 600
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Squad.tick(squad) end)

          decreased_count =
            Enum.count(results, fn {:ok, updated_squad, []} ->
              updated_squad.resources.other == squad.resources.other - members_count
            end)

          decreased_proportion = decreased_count / num_runs

          assert decreased_proportion >= 0.0001
          assert decreased_proportion <= 0.4
        end
      end
    end

    property "removes members when low resources" do
      members_count = 2
      [member, member2] = build_list(members_count, :squad_member)

      resources = build(:squad_resources, ammo: 100, supplies: 200, other: 0)

      squad =
        build(:squad,
          members: %{member.npc.uuid => member, member2.npc.uuid => member2},
          resources: resources,
          moves_with_low_resources: 10000
        )

      check all(_n <- StreamData.integer(1..100)) do
        num_runs = 500
        generator = list_of(constant(:ok), min_length: num_runs, max_length: num_runs)

        check all(_ <- generator) do
          results = Enum.map(1..num_runs, fn _ -> Squad.tick(squad) end)

          removed_count =
            Enum.count(results, fn {:ok, updated_squad, []} ->
              Enum.count(updated_squad.members) == 1 &&
                Enum.any?(updated_squad.events, fn
                  {:member_left_squad, _} -> true
                  _ -> false
                end)
            end)

          removed_proportion = removed_count / num_runs

          assert removed_proportion >= 0.0001
          assert removed_proportion <= 0.4
        end
      end
    end
  end

  describe "use_supply/2" do
    test "decreases supplies count" do
      squad = build(:squad, resources: build(:squad_resources, supplies: 10))
      assert {:ok, %Squad{resources: %Squad.Resources{supplies: 9}}, @base_heal} = Squad.use_supply(squad)
    end

    test "increases heal by members profession" do
      npc = build(:npc, character: build(:character, profession: :doctor))
      member = build(:squad_member, npc: npc)
      squad = build(:squad, resources: build(:squad_resources, supplies: 10), members: %{member.npc.uuid => member})

      assert {:ok, %Squad{resources: %Squad.Resources{supplies: 9}}, heal} = Squad.use_supply(squad)
      assert heal > @base_heal
    end

    test "returns error when no supplies" do
      squad = build(:squad, resources: build(:squad_resources, supplies: 0))
      assert {:error, :no_supplies} = Squad.use_supply(squad)
    end
  end
end
