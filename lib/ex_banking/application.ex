defmodule ExBanking.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: ExBanking.AccountRegistry},
      {Registry, keys: :unique, name: ExBanking.AccountStateRegistry},
      {Registry, keys: :unique, name: ExBanking.AccountAccessRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: ExBanking.AccountDynamicSupervisor}
    ]

    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
