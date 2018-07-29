defmodule TritonTest.Schema.User do
  @moduledoc false

  use Triton.Schema

  table :users, keyspace: TritonTest.Keyspaces.Default do
    field(:id, :text, validators: [presence: true])
    field(:email, :text, validators: [presence: true])
    field(:friends, {:list, "<FROZEN<friend>>"})

    partition_key([:id])
  end
end
