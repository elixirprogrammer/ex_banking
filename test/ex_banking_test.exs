defmodule ExBankingTest do
  use ExUnit.Case

  alias ExBanking.AccountDynamicSupervisor
  alias ExBanking.AccountRegistry
  alias ExBanking.AccountStateRegistry

  @user1 "John Doe"
  @user2 "Jane"
  @user3 "marlong"

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

  describe "deposit/3 errors validations" do
    test "error user not string" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(<<1::3>>, 1, "USD")
      assert {:error, :wrong_arguments} = ExBanking.deposit([], 1, "USD")
      assert {:error, :wrong_arguments} = ExBanking.deposit(%{}, 1, "USD")
    end

    test "error when currency not string" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(@user1, 1, <<1::3>>)
      assert {:error, :wrong_arguments} = ExBanking.deposit(@user1, 1, [])
      assert {:error, :wrong_arguments} = ExBanking.deposit(@user1, 1, %{})
    end

    test "error when amount not a number" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(@user1, "", "USD")
    end

    test "error when empty user name" do
      assert {:error, :wrong_arguments} = ExBanking.deposit("", 1, "USD")
    end

    test "error when empty user currency" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(@user1, 1, "")
    end

    test "error when negative amount" do
      assert {:error, :wrong_arguments} = ExBanking.deposit(@user1, -100, "")
    end

    test "error when user does not exists" do
      assert {:error, :user_does_not_exist} = ExBanking.deposit("no", 1, "USD")
    end
  end

  describe "deposit/3" do
    setup do
      :ok = ExBanking.create_user(@user2)
      on_exit(fn -> terminate_children(@user2) end)
    end

    test "error when moren than 10 requests" do
      result =
        for n <- 1..11 do
          Task.async(fn -> ExBanking.deposit(@user2, n, "USD") end)
        end
        |> Enum.map(&Task.await/1)

      assert 1 =
               result
               |> Enum.count(fn result -> result == {:error, :too_many_requests_to_user} end)
    end

    test "creates USD currency successfully" do
      assert {:ok, 10.0} = ExBanking.deposit(@user2, 10, "USD")
    end

    test "increases USD balance" do
      assert {:ok, 10.0} = ExBanking.deposit(@user2, 10, "USD")
      assert {:ok, 20.0} = ExBanking.deposit(@user2, 10, "USD")
    end

    test "creates multiple currencies" do
      assert {:ok, 10.0} = ExBanking.deposit(@user2, 10.0, "USD")
      assert {:ok, 10.0} = ExBanking.deposit(@user2, 10, "EUR")
      assert {:ok, 40.0} = ExBanking.deposit(@user2, 30, "EUR")
      assert {:ok, 30.0} = ExBanking.deposit(@user2, 20, "USD")
    end
  end

  describe "withdraw/3 errors validations" do
    test "error user not string" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(<<1::3>>, 1, "USD")
      assert {:error, :wrong_arguments} = ExBanking.withdraw([], 1, "USD")
      assert {:error, :wrong_arguments} = ExBanking.withdraw(%{}, 1, "USD")
    end

    test "error when currency not string" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user1, 1, <<1::3>>)
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user1, 1, [])
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user1, 1, %{})
    end

    test "error when amount not a number" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user1, "", "USD")
    end

    test "error when empty user name" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw("", 1, "USD")
    end

    test "error when empty user currency" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user1, 1, "")
    end

    test "error when negative amount" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user1, -100, "")
    end

    test "error when user does not exists" do
      assert {:error, :user_does_not_exist} = ExBanking.withdraw("no", 1, "USD")
    end
  end

  describe "withdraw/3" do
    setup do
      :ok = ExBanking.create_user(@user3)
      on_exit(fn -> terminate_children(@user3) end)
    end

    test "error when currency not created for user" do
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user3, 10, "USD")
      assert {:ok, 10.0} = ExBanking.deposit(@user3, 10, "USD")
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user3, 5, "EUR")
    end

    test "error when not enough money" do
      assert {:ok, 10.0} = ExBanking.deposit(@user3, 10, "USD")
      assert {:error, :not_enough_money} = ExBanking.withdraw(@user3, 11, "USD")
      assert {:error, :not_enough_money} = ExBanking.withdraw(@user3, 10.20, "USD")
    end

    test "0 balance when all money withdrawn" do
      assert {:ok, 10.0} = ExBanking.deposit(@user3, 10, "USD")
      assert {:ok, 0.0} = ExBanking.withdraw(@user3, 10, "USD")
    end

    test "balance for not given currencies unchanged" do
      assert {:ok, 10.0} = ExBanking.deposit(@user3, 10, "USD")
      assert {:ok, 10.0} = ExBanking.deposit(@user3, 10, "Dominican")
      assert {:ok, 10.0} = ExBanking.deposit(@user3, 10, "Canadian")

      assert {:ok, 9.0} = ExBanking.withdraw(@user3, 1, "USD")
      assert {:ok, 9.0} = ExBanking.withdraw(@user3, 1, "Dominican")
      assert {:ok, 9.0} = ExBanking.withdraw(@user3, 1, "Canadian")
      assert {:ok, 8.0} = ExBanking.withdraw(@user3, 1, "USD")
      assert {:ok, 8.0} = ExBanking.withdraw(@user3, 1, "Dominican")
      assert {:ok, 8.0} = ExBanking.withdraw(@user3, 1, "Canadian")
    end
  end

  defp terminate_children(user) do
    [{account_pid, _}] = Registry.lookup(AccountRegistry, user)
    [{account_state_pid, _}] = Registry.lookup(AccountStateRegistry, user)

    :ok = DynamicSupervisor.terminate_child(AccountDynamicSupervisor, account_pid)
    :ok = DynamicSupervisor.terminate_child(AccountDynamicSupervisor, account_state_pid)
  end
end
