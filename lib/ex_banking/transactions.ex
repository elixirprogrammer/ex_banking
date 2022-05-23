defmodule ExBanking.Transactions do
  @doc """
  This genserver will handle all transactions.
  """

  use GenServer

  alias ExBanking.Account
  alias ExBanking.AccountState
  alias ExBanking.AccountRegistry
  alias ExBanking.AccountDynamicSupervisor
  alias Decimal, as: D

  @spec start_link(options :: tuple()) ::
          {:ok, pid()} | :ignore | {:error, {:already_started, pid()} | term()}
  def start_link(options) do
    {:ok, {:via, Registry, {AccountRegistry, user}}} = Keyword.fetch(options, :name)
    GenServer.start_link(__MODULE__, user, options)
  end

  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency) do
    case Account.exists?(user) do
      true -> make_deposit(user, amount, currency)
      false -> {:error, :user_does_not_exist}
    end
  end

  @impl true
  def init(user) do
    # get the first message in the mailbox
    send(self(), :block)
    # Gets wallet list state from different process when initiated.
    {:ok, {user, AccountState.get_saved_wallet_list(user)}}
  end

  @impl true
  def handle_call({:deposit, {amount, currency}}, _from, state) do
    case validate_operations_requests(state) do
      :ok ->
        {user, wallet_list} = get_deposit_state(amount, currency, state)
        response = get_deposit_response(wallet_list, currency)
        {:reply, response, {user, wallet_list}}

      error ->
        error
    end
  end

  @impl true
  def handle_info(:block, state) do
    # block for one second
    Process.sleep(50)
    {:noreply, state}
  end

  # Saves the the wallet list state in a seperate process when terminates.
  @impl true
  def terminate(_reason, {user, wallet_list}) do
    AccountState.save_wallet_list(user, wallet_list)
  end

  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number} | {:error, :too_many_requests_to_user}
  defp make_deposit(user, amount, currency) do
    via_tuple = AccountDynamicSupervisor.via_tuple(user, AccountRegistry)
    GenServer.call(via_tuple, {:deposit, {amount, currency}})
  end

  # Checks the message queue length of current user process
  @spec validate_operations_requests(state :: tuple()) ::
          :ok | {:reply, {:error, :too_many_requests_to_user}, state :: tuple()}
  defp validate_operations_requests(state) do
    case Process.info(self(), :message_queue_len) do
      {_, length} when length > 9 ->
        {:reply, {:error, :too_many_requests_to_user}, state}

      _ ->
        :ok
    end
  end

  # Increases balance amount for found currency already in the system
  # Adds new balance and currency to wallet list if currency not found
  @spec get_deposit_state(amount :: String.t(), currency :: String.t(), state :: tuple()) ::
          {user :: String.t(), wallet_list :: list()}
  defp get_deposit_state(new_amount, new_currency, {user, wallet_list}) do
    find_currency =
      wallet_list
      |> Enum.any?(fn {_amount, currency} ->
        currency == new_currency
      end)

    case find_currency do
      true ->
        # Increases balance amount for same currency balance
        wallet_list =
          wallet_list
          |> Stream.map(fn {amount, currency} ->
            if currency == new_currency do
              {add_amount(amount, new_amount), currency}
            else
              {amount, currency}
            end
          end)

        {user, wallet_list}

      false ->
        {user, [{new_amount, new_currency} | wallet_list]}
    end
  end

  # Finds balance amount, currency tuple inside wallet list and converts amount to
  # 2 decimal precision number.
  @spec get_deposit_response(wallet_list :: list(), currency :: String.t()) :: {:ok, number}
  defp get_deposit_response(wallet_list, currency) do
    {amount, _} =
      wallet_list
      |> Enum.find(fn {_amount, c} -> c == currency end)

    {:ok, get_amount_response(amount)}
  end

  # Converts amounts to decimals and makes the adding operation using the decimal package.
  @spec add_amount(current_amount:: number, new_amount:: number) :: number
  defp add_amount(current_amount, new_amount) do
    current_amount = current_amount |> to_string() |> D.new()
    new_amount = new_amount |> to_string() |> D.new()

    D.add(current_amount, new_amount) |> Decimal.to_float()
  end

  @spec get_amount_response(amount :: number) :: number
  defp get_amount_response(amount) do
    amount
    |> to_string()
    |> D.new()
    |> D.round(2)
    |> D.to_float()
  end
end