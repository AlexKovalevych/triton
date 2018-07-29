defmodule Triton.Setup do
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

  def table(conn, %{__metadata__: %Metadata{keyspace: keyspace}} = table) do
    try do
      statement = build_table_cql(table)
      keyspace_name = keyspace.metadata().name
      Xandra.execute!(conn, "USE #{keyspace_name};", [], pool: keyspace.metadata().pool)
      Xandra.execute!(conn, statement, [], pool: keyspace.metadata().pool)
    rescue
      err -> IO.inspect(err)
    end
  end

  def type(conn, %{__metadata__: %Metadata{keyspace: keyspace}} = type) do
    try do
      statement = build_type_cql(type)
      keyspace_name = keyspace.metadata().name
      Xandra.execute!(conn, "USE #{keyspace_name};", [], pool: keyspace.metadata().pool)
      Xandra.execute!(conn, statement, [], pool: keyspace.metadata().pool)
    rescue
      err -> IO.inspect(err)
    end
  end

  def materialized_view(conn, %{__metadata__: %Metadata{keyspace: keyspace}} = table) do
    try do
      statement = build_materialized_view_cql(table)
      keyspace_name = keyspace.metadata().name
      Xandra.execute!(conn, "USE #{keyspace_name};", [], pool: keyspace.metadata().pool)
      Xandra.execute!(conn, statement, [], pool: keyspace.metadata().pool)
    rescue
      err -> IO.inspect(err)
    end
  end

  defp build_keyspace_cql(%{__metadata__: %Metadata{name: name, keyspace: keyspace}}) do
    create_cql = "CREATE KEYSPACE IF NOT EXISTS #{name}"
    create_cql <> with_options_cql(keyspace[:__with_options__])
  end

  defp build_type_cql(%{__metadata__: %Metadata{name: name, fields: fields, keyspace: keyspace}}) do
    create_cql = "CREATE TYPE IF NOT EXISTS #{name}"
    create_cql <> " (" <> fields_cql(fields) <> " )"
  end

  defp build_table_cql(%{__metadata__: %Metadata{name: name, fields: fields, table: table}}) do
    create_cql = "CREATE TABLE IF NOT EXISTS #{name}"
    primary_key_comma = if is_list(table[:__partition_key__]), do: ",", else: ""

    create_cql <>
      " (" <>
      fields_cql(fields) <>
      primary_key_comma <>
      primary_key_cql(table[:__partition_key__], table[:__cluster_columns__]) <>
      ")" <> with_options_cql(table[:__with_options__])
  end

  defp build_materialized_view_cql(
         %{__metadata__: %Metadata{name: name, fields: fields, from: from, table: table}} = a
       ) do
    create_cql = "CREATE MATERIALIZED VIEW IF NOT EXISTS #{name}"

    create_cql <>
      select_cql(fields) <>
      from_cql(from.metadata().name) <>
      where_cql(table[:__partition_key__], table[:__cluster_columns__]) <>
      primary_key_cql(table[:__partition_key__], table[:__cluster_columns__]) <>
      with_options_cql(table[:__with_options__])
  end

  defp with_options_cql(opts) when is_list(opts) do
    cql =
      opts
      |> Enum.map(fn opt -> with_option_cql(opt) end)
      |> Enum.join(" AND ")

    " WITH " <> cql
  end

  defp with_options_cql(_), do: ""

  defp with_option_cql({:clustering_order_by, opts}) do
    fields_and_order =
      opts |> Enum.map(fn {field, order} -> "#{field} #{order}" end) |> Enum.join(", ")

    "CLUSTERING ORDER BY (" <> fields_and_order <> ")"
  end

  defp with_option_cql({option, value}), do: "#{String.upcase(to_string(option))} = #{value}"

  defp fields_cql(fields), do: fields |> Enum.map(&field_cql/1) |> Enum.join(", ")

  defp field_cql({field, %{type: {collection_type, type}}}),
    do: "#{field} #{collection_type}#{type}"

  defp field_cql({field, %{type: type}}), do: "#{field} #{type}"

  defp primary_key_cql(partition_key, cluster_columns)
       when is_list(partition_key) and is_list(cluster_columns) do
    " PRIMARY KEY((" <>
      Enum.join(partition_key, ", ") <> "), #{Enum.join(cluster_columns, ", ")})"
  end

  defp primary_key_cql(partition_key, nil) when is_list(partition_key) do
    " PRIMARY KEY((" <> Enum.join(partition_key, ", ") <> "))"
  end

  defp primary_key_cql(_, _), do: ""

  defp select_cql(fields) when is_list(fields), do: " AS SELECT " <> Enum.join(fields, ", ")
  defp select_cql(_), do: " AS SELECT *"

  defp from_cql(table_name), do: " FROM #{table_name}"

  defp where_cql(pk, cc) when is_list(pk) and is_list(cc) do
    fields_not_null =
      (pk ++ cc)
      |> Enum.map(fn field -> "#{field} IS NOT NULL" end)
      |> Enum.join(" AND ")

    " WHERE #{fields_not_null}"
  end

  defp where_cql(pk, _) when is_list(pk) do
    fields_not_null =
      pk
      |> Enum.map(fn field -> "#{field} IS NOT NULL" end)
      |> Enum.join(" AND ")

    " WHERE #{fields_not_null}"
  end

  defp where_cql(_, _), do: ""
end
