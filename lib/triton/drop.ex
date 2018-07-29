defmodule Triton.Drop do
  @moduledoc false

  alias Triton.Metadata

  def keyspace(conn, %{} = keyspace) do
    try do
      statement = build_keyspace_cql(keyspace)
      Xandra.execute!(conn, statement, [], pool: keyspace.__metadata__.pool)
    rescue
      err -> IO.inspect(err)
    end
  end

  def table(conn, %{} = table) do
    try do
      statement = build_table_cql(table)
      Xandra.execute!(conn, statement, [], pool: table.__metadata__.keyspace.metadata().pool)
    rescue
      err -> IO.inspect(err)
    end
  end

  defp build_keyspace_cql(%{__metadata__: %Metadata{name: name}}) do
    "DROP KEYSPACE IF EXISTS #{name};"
  end

  defp build_table_cql(%{__metadata__: %Metadata{name: name}}) do
    "DROP TABLE IF EXISTS #{name};"
  end
end
