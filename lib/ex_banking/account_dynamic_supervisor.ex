defmodule ExBanking.AccountDynamicSupervisor do
  @moduledoc """
  Dynamic supervisor to start account and account state workers
  """
  alias ExBanking.Transactions
  alias ExBanking.AccountAccess
  alias ExBanking.AccountState
  alias ExBanking.AccountStateRegistry
  alias ExBanking.AccountAccessRegistry
  alias ExBanking.AccountRegistry

  @spec start_account_state_child(user :: String.t()) ::
          {:ok, pid()}
          | {:ok, pid(), info :: term()}
          | :ignore
          | {:error, {:already_started, pid()} | :max_children | term()}
  def start_account_state_child(user) do
    via_tuple = {AccountState, name: via_tuple(user, AccountStateRegistry)}
    DynamicSupervisor.start_child(__MODULE__, via_tuple)
  end

  @spec start_account_access_child(user :: String.t()) ::
          {:ok, pid()}
          | {:ok, pid(), info :: term()}
          | :ignore
          | {:error, {:already_started, pid()} | :max_children | term()}
  def start_account_access_child(user) do
    via_tuple = {AccountAccess, name: via_tuple(user, AccountAccessRegistry)}
    DynamicSupervisor.start_child(__MODULE__, via_tuple)
  end

  @spec start_account_child(user :: String.t()) ::
          {:ok, pid()}
          | {:ok, pid(), info :: term()}
          | :ignore
          | {:error, {:already_started, pid()} | :max_children | term()}
  def start_account_child(user) do
    via_tuple = {Transactions, name: via_tuple(user, AccountRegistry)}
    DynamicSupervisor.start_child(__MODULE__, via_tuple)
  end

  @spec via_tuple(user :: String.t(), registry :: module()) :: tuple()
  def via_tuple(user, registry) do
    {:via, Registry, {registry, user}}
  end
end
