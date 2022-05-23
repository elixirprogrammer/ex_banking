defmodule ExBanking do
  @moduledoc """
  Public interface and behaviour for `ExBanking` operations.
  """

  alias ExBanking.Account
  alias ExBanking.Transactions

  @doc """
  Creates new user in the system
  New user has zero balance of any currency
  """
  @spec create_user(user :: String.t()) ::
          :ok | {:error, :wrong_arguments | :user_already_exists}
  def create_user(user) when is_binary(user) do
    # Cannot invoke remote function String.length/1 inside guards
    # Checks that string is not empty before creating new user
    case String.length(user) > 0 do
      true -> Account.new(user)
      false -> {:error, :wrong_arguments}
    end
  end

  def create_user(_), do: {:error, :wrong_arguments}

  @doc """
  Increases user's balance in given currency by amount value
  Returns new_balance of the user in given format
  """
  @spec deposit(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def deposit(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) do
    with true <- String.length(user) > 0,
         true <- String.length(currency) > 0 do
      Transactions.deposit(user, amount, currency)
    else
      false -> {:error, :wrong_arguments}
    end
  end

  def deposit(_, _, _), do: {:error, :wrong_arguments}

  @doc """
  Decreases user's balance in given currency by amount value
  Returns new_balance of the user in given format
  """
  @spec withdraw(user :: String.t(), amount :: number(), currency :: String.t()) ::
          {:ok, new_balance :: number()}
          | {:error,
             :wrong_arguments
             | :user_does_not_exist
             | :not_enough_money
             | :too_many_requests_to_user}
  def withdraw(user, amount, currency)
      when is_binary(user) and is_number(amount) and is_binary(currency) do
    with true <- String.length(user) > 0,
         true <- String.length(currency) > 0 do
      Transactions.withdraw(user, amount, currency)
    else
      false -> {:error, :wrong_arguments}
    end
  end

  def withdraw(_, _, _), do: {:error, :wrong_arguments}

  @doc """
  Returns balance of the user in given format
  """
  @spec get_balance(user :: String.t(), currency :: String.t()) ::
          {:ok, balance :: number()}
          | {:error, :wrong_arguments | :user_does_not_exist | :too_many_requests_to_user}
  def get_balance(user, currency) do
  end

  @doc """
  Decreases from_user's balance in given currency by amount value
  Increases to_user's balance in given currency by amount value
  Returns balance of from_user and to_user in given format
  """
  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number(),
          currency :: String.t()
        ) ::
          {:ok, from_user_balance :: number(), to_user_balance :: number()}
          | {:error,
             :wrong_arguments
             | :not_enough_money
             | :sender_does_not_exist
             | :receiver_does_not_exist
             | :too_many_requests_to_sender
             | :too_many_requests_to_receiver}
  def send(from_user, to_user, amount, currency) do
  end
end
