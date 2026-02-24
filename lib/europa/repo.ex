defmodule Europa.Repo do
  use Ecto.Repo,
    otp_app: :europa,
    adapter: Ecto.Adapters.Postgres
end
