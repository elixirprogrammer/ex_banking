defmodule ExBanking.Transactions do
  @doc """
  This genserver will handle all transactions.
  """

  use GenServer

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

  @spec deposit(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
  def deposit(user, amount, currency) do
    make_deposit(user, amount, currency)
  end

  @spec withdraw(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error,
             :wrong_arguments
             | :not_enough_money}
  def withdraw(user, amount, currency) do
    make_withdraw(user, amount, currency)
  end

  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error, :wrong_arguments}
  def get_balance(user, currency) do
    balance(user, currency)
  end

  @impl true
  def init(user) do
    # Gets wallet list state from different process when initiated.
    {:ok, {user, AccountState.get_saved_wallet_list(user)}}
  end

  @impl true
  def handle_call({:deposit, {amount, currency}}, _from, state) do
    get_deposit_response(amount, currency, state)
  end

  def handle_call({:withdraw, {amount, currency}}, _from, state) do
    get_withdraw_response(amount, currency, state)
  end

  def handle_call({:balance, currency}, _from, state) do
    get_balance_response(currency, state)
  end

  # Saves the the wallet list state in a seperate process when terminates.
  @impl true
  def terminate(_reason, {user, wallet_list}) do
    AccountState.save_wallet_list(user, wallet_list)
  end

  @spec make_deposit(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
  defp make_deposit(user, amount, currency) do
    via_tuple = AccountDynamicSupervisor.via_tuple(user, AccountRegistry)
    GenServer.call(via_tuple, {:deposit, {amount, currency}})
  end

  @spec make_withdraw(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
  defp make_withdraw(user, amount, currency) do
    via_tuple = AccountDynamicSupervisor.via_tuple(user, AccountRegistry)
    GenServer.call(via_tuple, {:withdraw, {amount, currency}})
  end

  @spec balance(user :: String.t(), currency :: String.t()) ::
          {:ok, new_balance :: number()} | {:error, :too_many_requests_to_user}
  defp balance(user, currency) do
    via_tuple = AccountDynamicSupervisor.via_tuple(user, AccountRegistry)
    GenServer.call(via_tuple, {:balance, currency})
  end

  @spec get_deposit_response(
          amount :: number(),
          currency :: String.t(),
          wallet_list_state :: list()
        ) :: {:reply, {:ok, amount :: number()}, {user :: String.t(), wallet_list :: list()}}
  defp get_deposit_response(amount, currency, {user, wallet_list_state}) do
    {user, wallet_list} = get_wallet_state(amount, currency, {user, wallet_list_state})
    # Finds balance amount, currency tuple inside wallet list and converts amount to
    # 2 decimal precision number.
    {amount, _} =
      wallet_list
      |> Enum.find(fn {_amount, c} -> c == currency end)

    response = {:ok, get_amount_response(amount)}

    {:reply, response, {user, wallet_list}}
  end

  # Increases balance amount for found currency already in the system
  # Adds new balance and currency to wallet list if currency not found
  @spec get_wallet_state(new_amount :: number(), new_currency :: String.t(), state :: tuple()) ::
          {user :: String.t(), wallet_list :: list()}
  defp get_wallet_state(new_amount, new_currency, {user, wallet_list}) do
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

  @spec get_withdraw_response(amount :: number(), currency :: String.t(), tuple()) ::
          {:reply, {:ok, amount :: number()} | {:error, :wrong_arguments | :not_enough_money},
           {user :: String.t(), wallet_list :: list()}}
  defp get_withdraw_response(amount, currency, {user, wallet_list}) do
    find_currency =
      wallet_list
      |> Enum.any?(fn {_amount, old_currency} ->
        old_currency == currency
      end)

    case find_currency do
      true ->
        get_subtract_response(amount, currency, {user, wallet_list})

      false ->
        {:reply, {:error, :wrong_arguments}, {user, wallet_list}}
    end
  end

  @spec get_subtract_response(amount :: number(), currency :: String.t(), tuple()) ::
          {:reply, {:ok, amount :: number()} | {:error, :not_enough_money},
           {user :: String.t(), wallet_list :: list()}}
  defp get_subtract_response(amount, currency, {user, wallet_list}) do
    # gets current amount for currency
    {current_amount, _} =
      wallet_list
      |> Enum.find(fn {_amount, c} -> c == currency end)

    case subtract_amount(current_amount, amount) do
      result when result < 0 ->
        {:reply, {:error, :not_enough_money}, {user, wallet_list}}

      result ->
        # Updates amount with result for given currency balance
        new_wallet_list =
          wallet_list
          |> Stream.map(fn {current_amount, current_currency} ->
            if current_currency == currency do
              {result, currency}
            else
              {current_amount, current_currency}
            end
          end)

        {:reply, {:ok, get_amount_response(result)}, {user, new_wallet_list}}
    end
  end

  @spec get_balance_response(currency :: String.t(), tuple()) ::
          {:reply, {:ok, amount :: number()} | {:error, :wrong_arguments},
           {user :: String.t(), wallet_list :: list()}}
  defp get_balance_response(currency, {user, wallet_list}) do
    find_currency =
      wallet_list
      |> Enum.any?(fn {_amount, old_currency} ->
        old_currency == currency
      end)

    case find_currency do
      true ->
        # gets current amount for currency
        {amount, _} =
          wallet_list
          |> Enum.find(fn {_amount, c} -> c == currency end)

        {:reply, {:ok, get_amount_response(amount)}, {user, wallet_list}}

      false when wallet_list == [] ->
        {:reply, {:ok, 0.00}, {user, wallet_list}}

      false ->
        {:reply, {:error, :wrong_arguments}, {user, wallet_list}}
    end
  end

  # Converts amounts to decimals and makes the adding operation using the decimal package.
  @spec add_amount(current_amount :: number(), new_amount :: number()) :: number()
  defp add_amount(current_amount, new_amount) do
    do_operation(current_amount, new_amount, &D.add(&1, &2))
  end

  # Converts amounts to decimals and makes the adding operation using the decimal package.
  @spec add_amount(current_amount :: number(), new_amount :: number()) :: number()
  defp subtract_amount(current_amount, new_amount) do
    do_operation(current_amount, new_amount, &D.sub(&1, &2))
  end

  # Calls decimal arithmetic dynamically
  defp do_operation(current_amount, new_amount, func) do
    current_amount = current_amount |> to_string() |> D.new()
    new_amount = new_amount |> to_string() |> D.new()

    func.(current_amount, new_amount) |> Decimal.to_float()
  end

  @spec get_amount_response(amount :: number()) :: number()
  defp get_amount_response(amount) do
    amount
    |> to_string()
    |> D.new()
    |> D.round(2)
    |> D.to_float()
  end
end
