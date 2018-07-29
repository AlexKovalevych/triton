defmodule Triton.Helper do
  @moduledoc false

  def query_type(query) do
    cond do
      query[:stream] -> :stream
      query[:count] -> :count
      query[:select] -> :select
      query[:insert] -> :insert
      query[:update] -> :update
      query[:delete] -> :delete
      true -> {:error, Triton.Error.invalid_cql_operation()}
    end
  end

  def await_connected(conn, pool, tries \\ 4) do
    try do
      Xandra.execute(conn, "SELECT now() FROM system.local;", [], pool: pool)
    rescue
      Xandra.ConnectionError ->
        if tries > 0 do
          Process.sleep(50)
          await_connected(conn, pool, tries - 1)
        else
          raise "exceeded maximum number of attempts"
        end
    end
  end
end
