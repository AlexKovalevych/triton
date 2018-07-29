defmodule TritonTest.Schema.Friend do
  @moduledoc false

  use Triton.Schema

  type :friend, keyspace: TritonTest.Keyspaces.Default do
    field(:name, :text, validators: [presence: true])
    field(:periods, {:list, "<FROZEN<period>>"})
  end
end
