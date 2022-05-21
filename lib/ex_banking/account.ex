defmodule ExBanking.Account do
  @moduledoc """
  Defined for user banking operations.
  """

  import ExBanking.AccountDynamicSupervisor

  @doc """
  Registers new user worker and user state worker if user not already in the system.
  """
  @spec new(user :: String.t()) :: :ok | {:error, :user_already_exists}
  def new(user) do
    get_account_worker = Registry.lookup(ExBanking.AccountRegistry, user)
    account_worker_exists? = account_worker_exists?(get_account_worker)
    start_children?(account_worker_exists?, user)
  end

  # Returns boolean if pid found with registry lookup
  @spec account_worker_exists?(list()) :: boolean()
  defp account_worker_exists?([{_pid, _}]), do: true
  defp account_worker_exists?([]), do: false

  # Error when pid found, starts account state child when not found
  defp start_children?(true, _user), do: {:error, :user_already_exists}

  defp start_children?(false, user) do
    start_account_state_worker(start_account_state_child(user), user)
  end

  # Starts account worker when account state child started successfully if not error
  defp start_account_state_worker({:ok, _pid}, user) do
    start_account_worker(start_account_child(user))
  end

  defp start_account_state_worker(error, _), do: error

  # Returns :ok when account worker started succesfully if not error
  defp start_account_worker({:ok, _pid}), do: :ok
  defp start_account_worker(error), do: error
end
