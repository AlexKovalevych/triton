defmodule TritonTest.Schema.Period do
  @moduledoc false

  use Triton.Schema

  type :period, keyspace: TritonTest.Keyspaces.Default do
    field(:start, :timestamp, validators: [presence: true])
    field(:end, :timestamp)
  end
end
