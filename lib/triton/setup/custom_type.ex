defmodule Triton.Setup.CustomType do
  @moduledoc false

  @doc """
  Attempts to create custom type at compile time by connecting to DB with Xandra
  """
  def setup(blueprint) do
    try do
      node =
        Application.get_env(:triton, :clusters)
        |> Enum.find(&(&1[:conn] == blueprint.__keyspace__.__struct__.__conn__))

      statement = build_cql(blueprint |> Map.delete(:__struct__))
      {:ok, conn} = Xandra.start_link(nodes: [node[:nodes] |> Enum.random()])
      Xandra.execute!(conn, "USE #{node[:keyspace]};", _params = [])
      Xandra.execute!(conn, statement, _params = [])
    rescue
      err -> IO.inspect(err)
    end
  end

  ## PRIVATE - Build CQL

  defp build_cql(blueprint) do
    create_cql(blueprint[:__name__]) <> " (" <> fields_cql(blueprint[:__fields__]) <> ")"
  end

  defp create_cql(name), do: "CREATE TYPE IF NOT EXISTS #{name}"

  defp fields_cql(fields),
    do: fields |> Enum.map(fn field -> field_cql(field) end) |> Enum.join(", ")

  defp field_cql({field, %{type: {collection_type, type}}}),
    do: "#{field} #{collection_type}#{type}"

  defp field_cql({field, %{type: type}}), do: "#{field} #{type}"
end
