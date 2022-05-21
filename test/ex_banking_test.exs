defmodule ExBankingTest do
  use ExUnit.Case

  alias ExBanking.AccountDynamicSupervisor
  alias ExBanking.AccountRegistry
  alias ExBanking.AccountStateRegistry

  @user1 "John Doe"

  describe "create_user/1" do
    test "creates user successfully" do
      assert :ok = ExBanking.create_user(@user1)
      assert :ok = terminate_children(@user1)
    end

    test "error when empty string" do
      assert {:error, :wrong_arguments} = ExBanking.create_user("")
    end

    test "error when not a string" do
      assert {:error, :wrong_arguments} = ExBanking.create_user(<<1::3>>)
      assert {:error, :wrong_arguments} = ExBanking.create_user([])
      assert {:error, :wrong_arguments} = ExBanking.create_user(%{})
    end

    test "error when user already exists" do
      assert :ok = ExBanking.create_user(@user1)

      assert {:error, :user_already_exists} = ExBanking.create_user(@user1)

      assert :ok = terminate_children(@user1)
    end

  end

  defp terminate_children(user) do
    [{account_pid, _}] = Registry.lookup(AccountRegistry, user)
    [{account_state_pid, _}] = Registry.lookup(AccountStateRegistry, user)

    :ok = DynamicSupervisor.terminate_child(AccountDynamicSupervisor, account_pid)
    :ok = DynamicSupervisor.terminate_child(AccountDynamicSupervisor, account_state_pid)
  end
end
