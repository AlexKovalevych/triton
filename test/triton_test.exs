defmodule TritonTest do
  use ExUnit.Case

  alias TritonTest.Schema.Friend
  alias TritonTest.Schema.Period
  alias TritonTest.Schema.User
  alias TritonTest.Schema.UserByEmail
  alias TritonTest.Keyspaces.Default
  alias Triton.Helper
  alias Triton.Drop
  alias Triton.Setup
  import Triton.Query

  setup_all do
    conn = Triton.Conn

    {:ok, _} =
      Xandra.start_link(
        name: conn,
        nodes: ["127.0.0.1:9042"],
        pool: Xandra.Cluster,
        pool_size: 1
      )

    Helper.await_connected(conn, Xandra.Cluster)

    assert %{} = Drop.keyspace(conn, %Default{})

    assert %Xandra.SchemaChange{
             effect: "CREATED",
             options: %{keyspace: "default"},
             target: "KEYSPACE"
           } = Setup.keyspace(conn, %Default{})

    assert %Xandra.SchemaChange{
             effect: "CREATED",
             options: %{keyspace: "default", subject: "period"},
             target: "TYPE"
           } = Setup.type(conn, %Period{})

    assert %Xandra.SchemaChange{
             effect: "CREATED",
             options: %{keyspace: "default", subject: "friend"},
             target: "TYPE"
           } = Setup.type(conn, %Friend{})

    assert %Xandra.SchemaChange{
             effect: "CREATED",
             options: %{keyspace: "default", subject: "users"},
             target: "TABLE"
           } = Setup.table(conn, %User{})

    %{conn: conn}
  end

  describe "test setup" do
    test "success materialized view setup", %{conn: conn} do
      assert %Xandra.SchemaChange{
               effect: "CREATED",
               options: %{keyspace: "default", subject: "users_by_email"},
               target: "TABLE"
             } = Setup.materialized_view(conn, %UserByEmail{})
    end
  end

  describe "database operations" do
    test "validation errors" do
      assert {:error,
              [
                %{message: "Invalid input. email must be present.", path: "email"},
                %{
                  message: "Invalid input. friends[0].name must be present.",
                  path: "friends[0].name"
                },
                %{
                  message: "Invalid input. friends[0].periods[1].start must be present.",
                  path: "friends[0].periods[1].start"
                }
              ]} =
               User
               |> insert(
                 id: "12345",
                 friends: %{
                   "1" => %Friend{
                     periods: [%Period{start: :os.system_time(:millisecond)}, %Period{}]
                   }
                 }
               )
               |> User.save()
    end

    test "success create user" do
      assert {:ok, :success} =
               User
               |> insert(
                 id: "12345",
                 email: "test@example.com",
                 friends: %{
                   "1" => %Friend{
                     name: "foo",
                     periods: [%Period{start: :os.system_time(:millisecond)}]
                   }
                 },
                 aliases: %{"1" => "foo", "2" => "bar"}
               )
               |> User.save()
    end

    test "success get user" do
      User
      |> insert(
        id: "123",
        email: "test@example.com",
        friends: %{
          "1" => %Friend{
            name: "foo",
            periods: [%Period{start: :os.system_time(:millisecond)}]
          }
        },
        aliases: %{"1" => "foo", "2" => "bar"}
      )
      |> User.save()

      assert {:ok,
              %{
                aliases: %{"1" => "foo", "2" => "bar"},
                email: "test@example.com",
                friends: %{
                  "1" => %{
                    "name" => "foo",
                    "periods" => [
                      %{"end" => nil, "start" => %DateTime{}}
                    ]
                  }
                },
                id: "123"
              }} =
               User
               |> prepared(id: "123")
               |> select([:id, :email, :friends, :aliases])
               |> where(id: :id)
               |> User.one()
    end

    test "success delete user" do
      User
      |> insert(id: "123", email: "test@example.com")
      |> User.save()

      assert {:ok, :success} =
               User
               |> prepared(id: "123")
               |> delete(:all)
               |> where(id: :id)
               |> User.del()
    end

    test "success update user" do
      assert {:ok, :success} =
               User
               |> insert(
                 id: "12",
                 email: "test@example.com",
                 aliases: %{"1" => "foo", "2" => "bar"},
                 friends: %{
                   "1" => %Friend{
                     name: "foo",
                     periods: [%Period{start: :os.system_time(:millisecond)}]
                   }
                 }
               )
               |> User.save()

      assert {:ok, :success} =
               User
               |> update(
                 email: "test2@example.com",
                 aliases: "aliases + {'3': 'baz'}",
                 friends:
                   "friends + {'2': {name:  'bar', periods: [{start: #{
                     :os.system_time(:millisecond)
                   }}]}}"
               )
               |> where(id: "12")
               |> User.save()
    end
  end
end
