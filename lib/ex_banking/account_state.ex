defmodule ExBanking.AccountState do
  @doc """
  Genserver to save transactions state when that worker is restarted.
  """

  use GenServer

  alias ExBanking.AccountDynamicSupervisor
  alias ExBanking.AccountStateRegistry

  @spec start_link(options :: tuple()) ::
          {:ok, pid()} | :ignore | {:error, {:already_started, pid()} | term()}
  def start_link(options), do: GenServer.start_link(__MODULE__, [], options)

  @spec save_wallet_list(user :: String.t(), wallet_list_state :: list()) :: :ok
  def save_wallet_list(user, wallet_list_state) do
    GenServer.cast(
      AccountDynamicSupervisor.via_tuple(user, AccountStateRegistry),
      {:save_wallet_list, wallet_list_state}
    )
  end

  @spec get_saved_wallet_list(user :: String.t()) :: list()
  def get_saved_wallet_list(user) do
    GenServer.call(
      AccountDynamicSupervisor.via_tuple(user, AccountStateRegistry),
      :get_saved_wallet_list
    )
  end

  @impl true
  def init(wallet_list) do
    {:ok, wallet_list}
  end

  @impl true
  def handle_cast({:save_wallet_list, wallet_list_state}, _wallet) do
    {:noreply, wallet_list_state}
  end

  @impl true
  def handle_call(:get_saved_wallet_list, _from, wallet) do
    {:reply, wallet, wallet}
  end
end
