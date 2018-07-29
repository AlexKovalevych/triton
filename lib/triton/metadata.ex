defmodule Triton.Metadata do
  @moduledoc false

  defstruct [:conn, :name, :table, :keyspace, :fields, :from, :pool]
end
