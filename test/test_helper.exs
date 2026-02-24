{:ok, _} = Application.ensure_all_started(:ex_machina)

Hammox.defmock(Europa.Server.PlanetManagerMock, for: Europa.Server.PlanetManager)
Application.put_env(:europa, Europa.Server.PlanetManager, implementation: Europa.Server.PlanetManagerMock)

Hammox.defmock(Europa.Server.PlayerManagerMock, for: Europa.Server.PlayerManager)
Application.put_env(:europa, Europa.Server.PlayerManager, implementation: Europa.Server.PlayerManagerMock)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Europa.Repo, :manual)
