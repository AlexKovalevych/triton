defmodule Triton.CQL.Insert do
  def build(query) do
    schema = query[:__metadata__].fields
    table = query[:__metadata__].name
    insert(query[:insert], table, schema) <> if_not_exists(query[:if_not_exists])
  end

  defp insert(fields, table, schema) when is_list(fields) do
    "INSERT INTO #{table} (#{field_keys(fields)}) VALUES (#{field_values(fields, schema)})"
  end

  defp field_keys(fields) when is_list(fields) do
    fields
    |> Enum.map(fn {k, _} -> k end)
    |> Enum.join(", ")
  end

  defp field_values(fields, schema) when is_list(fields) do
    fields
    |> Enum.map(fn {k, v} -> field_value(v, schema[k][:type]) end)
    |> Enum.join(", ")
  end

  def field_value(nil, _), do: "NULL"

  def field_value(value, {:map, type}) when is_map(value) do
    values =
      Enum.map(value, fn {k, v} ->
        "'#{k}': #{field_value(v, type)}"
      end)
      |> Enum.join(", ")

    "{" <> values <> "}"
  end

  def field_value([{:__metadata__, metadata} | _] = value, _) do
    values =
      value
      |> Keyword.delete(:__metadata__)
      |> Enum.map(fn {k, v} ->
        "#{k}: " <> to_string(field_value(v, metadata.fields[k][:type]))
      end)
      |> Enum.join(", ")

    "{" <> values <> "}"
  end

  def field_value([[{:__metadata__, _} | _] | _] = values, {_, subtype}) do
    prepared_values =
      values
      |> Enum.map(&field_value(&1, subtype))
      |> Enum.join(", ")

    "[" <> prepared_values <> "]"
  end

  def field_value(field, {_, _}), do: field
  def field_value(field, _) when is_boolean(field), do: "#{field}"
  def field_value(field, _) when is_binary(field), do: binary_value(field)
  def field_value(field, _) when is_atom(field), do: ":#{field}"
  def field_value(%DateTime{} = d, _), do: DateTime.to_unix(d, :millisecond)

  def field_value(%NaiveDateTime{} = d, type) do
    d
    |> DateTime.from_naive!("Etc/UTC")
    |> field_value(type)
  end

  def field_value(field, _), do: field

  defp if_not_exists(flag) when flag == true, do: " IF NOT EXISTS"
  defp if_not_exists(_), do: ""

  defp binary_value(v) do
    cond do
      String.valid?(v) && String.contains?(v, ["'", "\""]) -> "$$#{v}$$"
      true -> "'#{v}'"
    end
  end
end
