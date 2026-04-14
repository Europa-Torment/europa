defmodule Europa.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Europa.Tools.FilesCache

  @impl true
  def start(_type, _args) do
    children = [
      EuropaWeb.Telemetry,
      FilesCache,
      Europa.Repo,
      Europa.Server.Sup,
      Europa.Games.LeadersCache,
      {DNSCluster, query: Application.get_env(:europa, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Europa.PubSub},
      # Start a worker by calling: Europa.Worker.start_link(arg)
      # {Europa.Worker, arg},
      # Start to serve requests, typically the last entry
      EuropaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Europa.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EuropaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
