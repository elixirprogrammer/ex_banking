defmodule ExBanking.Account do
  @moduledoc """
  Defined for user banking operations.
  """

  import ExBanking.AccountDynamicSupervisor

  alias ExBanking.AccountRegistry

  @doc """
  Registers new user worker and user state worker if user not already in the system.
  """
  @spec new(user :: String.t()) :: :ok | {:error, :user_already_exists}
  def new(user) do
    # Error when pid found, starts account state child when not found
    case exists?(user) do
      true -> {:error, :user_already_exists}
      false -> start_account_state_worker(start_account_state_child(user), user)
    end
  end

  # Registry lookup for user
  @spec exists?(user :: String.t()) :: boolean()
  def exists?(user) do
    get_account_worker = Registry.lookup(AccountRegistry, user)
    worker_exists?(get_account_worker)
  end

  # Returns boolean if pid found with registry lookup
  @spec worker_exists?(list()) :: boolean()
  defp worker_exists?([{_pid, _}]), do: true
  defp worker_exists?([]), do: false

  # Starts account worker when account state child started successfully if not error
  defp start_account_state_worker({:ok, _pid}, user) do
    start_account_worker(start_account_child(user))
  end

  defp start_account_state_worker(error, _), do: error

  # Returns :ok when account worker started succesfully if not error
  defp start_account_worker({:ok, _pid}), do: :ok
  defp start_account_worker(error), do: error
end
