defmodule ExBanking.AccountAccess do
  @doc """
  Genserver to control access with rate limit to transactions.
  """

  use GenServer

  alias ExBanking.AccountDynamicSupervisor
  alias ExBanking.AccountAccessRegistry
  alias ExBanking.Transactions
  alias ExBanking.Account

  @max_per_second 10
  @reset_after 100

  @spec start_link(options :: tuple()) ::
          {:ok, pid()} | :ignore | {:error, {:already_started, pid()} | term()}
  def start_link(options) do
    {:ok, {:via, Registry, {AccountAccessRegistry, user}}} = Keyword.fetch(options, :name)
    GenServer.start_link(__MODULE__, user, options)
  end

  @spec deposit(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error, :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency) do
    case Account.exists?(user) do
      true ->
        GenServer.call(
          AccountDynamicSupervisor.via_tuple(user, AccountAccessRegistry),
          {:deposit, amount, currency}
        )

      false ->
        {:error, :user_does_not_exist}
    end
  end

  @spec withdraw(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user, amount, currency) do
    case Account.exists?(user) do
      true ->
        GenServer.call(
          AccountDynamicSupervisor.via_tuple(user, AccountAccessRegistry),
          {:withdraw, amount, currency}
        )

      false ->
        {:error, :user_does_not_exist}
    end
  end

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number()}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency) do
    case Account.exists?(user) do
      true ->
        GenServer.call(
          AccountDynamicSupervisor.via_tuple(user, AccountAccessRegistry),
          {:get_balance, currency}
        )

      false ->
        {:error, :user_does_not_exist}
    end
  end

  @impl true
  def init(user) do
    reset_requests_count()
    {:ok, {user, 0}}
  end

  @impl true
  def handle_info(:reset, {user, _count}) do
    reset_requests_count()
    {:noreply, {user, 0}}
  end

  @impl true
  def handle_call({:deposit, amount, currency}, _from, state) do
    log(amount, currency, state, &Transactions.deposit/3)
  end

  def handle_call({:withdraw, amount, currency}, _from, state) do
    log(amount, currency, state, &Transactions.withdraw/3)
  end

  def handle_call({:get_balance, currency}, _from, state) do
    case state do
      {user, count} when count <= @max_per_second ->
        {:reply, Transactions.get_balance(user, currency), {user, count + 1}}

      {_user, count} when count > @max_per_second ->
        {:reply, {:error, :too_many_requests_to_user}, state}
    end
  end

  # Replies transaction response or error, increases count when count <= @max_per_minute
  defp log(amount, currency, state, func) do
    case state do
      {user, count} when count <= @max_per_second ->
        {:reply, func.(user, amount, currency), {user, count + 1}}

      {_user, count} when count > @max_per_second ->
        {:reply, {:error, :too_many_requests_to_user}, state}
    end
  end

  # Restart user count to 0 each time that a minute has passed.
  defp reset_requests_count do
    Process.send_after(self(), :reset, @reset_after)
  end
end
