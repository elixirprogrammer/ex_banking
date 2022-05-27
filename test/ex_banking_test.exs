defmodule ExBankingTest do
  use ExUnit.Case

  alias ExBanking.AccountDynamicSupervisor
  alias ExBanking.AccountRegistry
  alias ExBanking.AccountStateRegistry

  @user1 "John Doe"
  @user2 "Jane"
  @user3 "marlong"
  @user4 "Tania"
  @user5 "Sender"
  @user6 "Receiver"

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
      assert {:error, :wrong_arguments} = ExBanking.deposit(@user1, -100, "USD")
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
      assert {:error, :wrong_arguments} = ExBanking.withdraw(@user1, -100, "USD")
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

  describe "get_balance/2 errors validations" do
    test "error user not string" do
      assert {:error, :wrong_arguments} = ExBanking.get_balance(<<1::3>>, "USD")
      assert {:error, :wrong_arguments} = ExBanking.get_balance([], "USD")
      assert {:error, :wrong_arguments} = ExBanking.get_balance(%{}, "USD")
    end

    test "error when currency not string" do
      assert {:error, :wrong_arguments} = ExBanking.get_balance(@user1, <<1::3>>)
      assert {:error, :wrong_arguments} = ExBanking.get_balance(@user1, [])
      assert {:error, :wrong_arguments} = ExBanking.get_balance(@user1, %{})
    end

    test "error when empty user name" do
      assert {:error, :wrong_arguments} = ExBanking.get_balance("", "USD")
    end

    test "error when empty currency" do
      assert {:error, :wrong_arguments} = ExBanking.get_balance(@user1, "")
    end

    test "error when user does not exists" do
      assert {:error, :user_does_not_exist} = ExBanking.get_balance("no", "USD")
    end
  end

  describe "get_balance/2" do
    setup do
      :ok = ExBanking.create_user(@user4)
      on_exit(fn -> terminate_children(@user4) end)
    end

    test "0 balance when no deposit" do
      assert {:ok, 0.00} = ExBanking.get_balance(@user4, "USD")
    end

    test "error when currency not found" do
      assert {:ok, 10} == ExBanking.deposit(@user4, 10, "USD")

      assert {:error, :wrong_arguments} = ExBanking.get_balance(@user4, "EUR")
    end

    test "gets balance successfully" do
      assert {:ok, 10} == ExBanking.deposit(@user4, 10, "USD")
      assert {:ok, 10} == ExBanking.deposit(@user4, 10, "EUR")

      assert {:ok, 10.0} = ExBanking.get_balance(@user4, "USD")
      assert {:ok, 10.0} = ExBanking.get_balance(@user4, "EUR")
    end
  end

  describe "send/4 errors validations" do
    test "error users not string" do
      assert {:error, :wrong_arguments} = ExBanking.send(<<1::3>>, <<1::3>>, 1, "USD")
      assert {:error, :wrong_arguments} = ExBanking.send([], [], 1, "USD")
      assert {:error, :wrong_arguments} = ExBanking.send(%{}, %{}, 1, "USD")
    end

    test "error when currency not string" do
      assert {:error, :wrong_arguments} = ExBanking.send(@user5, @user6, 1, <<1::3>>)
      assert {:error, :wrong_arguments} = ExBanking.send(@user5, @user6, 1, [])
      assert {:error, :wrong_arguments} = ExBanking.send(@user5, @user6, 1, %{})
    end

    test "error when amount not a number" do
      assert {:error, :wrong_arguments} = ExBanking.send(@user5, @user6, "", "USD")
    end

    test "error when empty users name" do
      assert {:error, :wrong_arguments} = ExBanking.send("", "", 1, "USD")
    end

    test "error when empty user currency" do
      assert {:error, :wrong_arguments} = ExBanking.send(@user5, @user6, 1, "")
    end

    test "error when negative amount" do
      assert {:error, :wrong_arguments} = ExBanking.send(@user5, @user6, -100, "USD")
    end

    test "error when sender does not exists" do
      assert {:error, :sender_does_not_exist} = ExBanking.send("test", @user6, 100, "USD")
    end
  end

  describe "send/4" do
    setup do
      :ok = ExBanking.create_user(@user5)
      :ok = ExBanking.create_user(@user6)
      on_exit(fn -> terminate_children(@user5) end)
      on_exit(fn -> terminate_children(@user6) end)
    end

    test "error when receiver does not exists" do
      assert {:ok, 10.0} = ExBanking.deposit(@user5, 10, "USD")

      assert {:error, :receiver_does_not_exist} = ExBanking.send(@user5, "user", 1, "USD")
    end

    test "error when currency not found" do
      assert {:error, :wrong_arguments} = ExBanking.send(@user5, @user6, 100, "USD")
    end

    test "error when not enough money" do
      assert {:ok, 0.1} = ExBanking.deposit(@user5, 0.1, "USD")
      assert {:error, :not_enough_money} = ExBanking.send(@user5, @user6, 100, "USD")
    end

    test "sends money successfully" do
      assert {:ok, 10.0} = ExBanking.deposit(@user5, 10, "USD")
      assert {:ok, 10.0} = ExBanking.deposit(@user6, 10, "USD")

      assert {:ok, 5.0, 15.0} = ExBanking.send(@user5, @user6, 5, "USD")
    end
  end

  describe "too many requests error" do
    setup do
      :ok = ExBanking.create_user("random user")
      on_exit(fn -> terminate_children("random user") end)
    end

    test "error when more than 10 requests" do
      operations = [:balance, :deposit, :withdraw]

      result =
        1..14
        |> Enum.map(fn _ ->
          Task.async(fn -> Enum.random(operations) |> random_operation() end)
        end)
        |> Enum.map(&Task.await/1)

      assert 4 =
               result
               |> Enum.count(fn result -> result == {:error, :too_many_requests_to_user} end)
    end
  end

  describe "sender too many requests errors" do
    setup do
      :ok = ExBanking.create_user("wrong sender")
      :ok = ExBanking.create_user("wrong receiver")
      on_exit(fn -> terminate_children("wrong sender") end)
      on_exit(fn -> terminate_children("wrong receiver") end)
    end

    test "error when too many requests to sender" do
      result =
        1..14
        |> Enum.map(fn _ ->
          Task.async(fn -> ExBanking.send("wrong sender", "wrong receiver", 1, "USD") end)
        end)
        |> Enum.map(&Task.await/1)

      assert 4 =
               result
               |> Enum.count(fn result -> result == {:error, :too_many_requests_to_sender} end)
    end
  end

  describe "account state" do
    setup do
      :ok = ExBanking.create_user("account state")
      on_exit(fn -> terminate_children("account state") end)
    end

    test "recovers account state when process terminated" do
      assert {:ok, 10.0} = ExBanking.deposit("account state", 10, "USD")

      assert :ok = GenServer.stop(AccountDynamicSupervisor.via_tuple("account state", AccountRegistry))
      Process.sleep(50)

      assert {:ok, 10.0} = ExBanking.get_balance("account state", "USD")
    end
  end

  defp random_operation(:deposit), do: ExBanking.deposit("random user", 100, "USD")
  defp random_operation(:withdraw), do: ExBanking.withdraw("random user", 1, "USD")
  defp random_operation(:balance), do: ExBanking.get_balance("random user", "USD")

  defp terminate_children(user) do
    [{account_pid, _}] = Registry.lookup(AccountRegistry, user)
    [{account_state_pid, _}] = Registry.lookup(AccountStateRegistry, user)

    :ok = DynamicSupervisor.terminate_child(AccountDynamicSupervisor, account_pid)
    :ok = DynamicSupervisor.terminate_child(AccountDynamicSupervisor, account_state_pid)
  end
end
