defmodule ExBanking.Transactions do
  @doc """
  This genserver will handle all transactions.
  """

  use GenServer

  alias ExBanking.AccountState
  alias ExBanking.AccountRegistry

  @spec start_link(options :: tuple()) ::
          {:ok, pid()} | :ignore | {:error, {:already_started, pid()} | term()}
  def start_link(options) do
    {:ok, {:via, Registry, {AccountRegistry, user}}} = Keyword.fetch(options, :name)
    GenServer.start_link(__MODULE__, user, options)
  end

  @impl true
  def init(user) do
    {:ok, AccountState.get_saved_wallet_list(user)}
  end
end
