defmodule Triton.Validator do
  def coerce(query) do
    with {:ok, query} <- validate(query) do
      fields = query[:__metadata__].fields
      {:ok, Enum.map(query, fn x -> coerce(x, fields) end)}
    end
  end

  def validate(query) do
    case Triton.Helper.query_type(query) do
      {:error, err} -> {:error, err.message}
      type -> validate(type, query, query[:__metadata__].fields)
    end
  end

  def validate(:insert, query, schema) do
    data = get_data(query, :insert)
    errors = get_errors(data, [], schema, nil)

    case errors do
      [] -> {:ok, query}
      err_list -> {:error, err_list |> Triton.Error.vex_error()}
    end
  end

  def validate(:update, query, schema) do
    data = get_data(query, :update)

    fields_to_validate = data |> Enum.map(&elem(&1, 0))

    vex =
      schema
      |> get_vex_validators()
      |> Enum.filter(&(elem(&1, 0) in fields_to_validate))

    case Vex.errors(data ++ [_vex: vex]) do
      [] -> {:ok, query}
      err_list -> {:error, err_list |> Triton.Error.vex_error()}
    end
  end

  def validate(_, query, _), do: {:ok, query}

  def coerce({:__metadata__, v}, _), do: {:__metadata__, v}
  def coerce({k, v}, fields), do: {k, coerce(v, fields)}

  def coerce(%{__metadata__: _} = value, fields) do
    value
    |> Map.from_struct()
    |> Enum.map(fn
      {:__metadata__, v} -> {:__metadata__, v}
      {k, v} -> coerce_fragment({k, v}, fields)
    end)
  end

  def coerce(fragments, fields) when is_list(fragments),
    do: fragments |> Enum.map(fn fragment -> coerce_fragment(fragment, fields) end)

  def coerce(non_list, _), do: non_list

  defp coerce_fragment({k, v}, fields) when is_list(v) do
    {k,
     v
     |> Enum.map(fn
       {c, value} ->
         coerce_fragment({k, c, value}, fields)

       %{__metadata__: metadata} = value ->
         coerce(value, metadata.fields)
     end)}
  end

  defp coerce_fragment({k, v}, fields) when is_map(v) do
    {k,
     v
     |> Enum.map(fn
       {c, %{__metadata__: metadata} = value} ->
         {c, coerce(value, metadata.fields)}

       {c, value} ->
         coerce_fragment({k, c, value}, fields)
     end)
     |> Enum.into(%{})}
  end

  defp coerce_fragment({k, v}, fields), do: {k, coerced_value(v, fields[k][:type])}
  defp coerce_fragment({k, c, v}, fields), do: {c, coerced_value(v, fields[k][:type])}
  defp coerce_fragment(x, _), do: x

  defp coerced_value(value, _) when is_atom(value), do: value
  defp coerced_value(value, :text) when not is_binary(value), do: to_string(value)
  defp coerced_value(value, :bigint) when is_binary(value), do: String.to_integer(value)
  defp coerced_value(value, :int) when is_binary(value), do: String.to_integer(value)
  defp coerced_value(value, :smallint) when is_binary(value), do: String.to_integer(value)
  defp coerced_value(value, :varint) when is_binary(value), do: String.to_integer(value)
  defp coerced_value(value, _), do: value

  defp get_data(query, type) do
    (query[:prepared] &&
       query[:prepared] ++ (query[type] |> Enum.filter(fn {_, v} -> !is_atom(v) end))) ||
      query[type]
  end

  defp get_vex_validators(schema) do
    schema
    |> Enum.filter(fn {_, opts} -> opts[:opts][:validators] end)
    |> Enum.map(fn {field, opts} -> {field, opts[:opts][:validators]} end)
  end

  defp get_errors([{_, _} | _] = data, _, schema, prefix) do
    field_errors =
      Vex.errors(data ++ [_vex: get_vex_validators(schema)])
      |> Enum.map(fn {:error, path, type, message} = error ->
        if prefix, do: {:error, get_prefix(prefix, path), type, message}, else: error
      end)

    nested_errors =
      data
      |> Enum.filter(fn
        {_, %{__metadata__: _}} ->
          true

        {_, [%{__metadata__: _} | _]} ->
          true

        _ ->
          false
      end)
      |> Enum.reduce([], fn
        {k, v}, acc when is_list(v) ->
          v
          |> Enum.with_index()
          |> Enum.reduce(acc, fn {element, index}, nested_acc ->
            nested_data = get_nested_data(element)

            nested_acc ++
              get_errors(
                nested_data,
                nested_acc,
                element.__metadata__.fields,
                get_prefix(prefix, k, index)
              )
          end)

        {k, v}, acc ->
          nested_data = get_nested_data(v)
          acc ++ get_errors(nested_data, acc, v.__metadata__.fields, get_prefix(prefix, k))
      end)

    field_errors ++ nested_errors
  end

  defp get_errors(_, errors, _, _), do: errors

  defp get_nested_data(data) do
    data
    |> Map.from_struct()
    |> Map.drop(~w(__metadata__ __struct__)a)
    |> Keyword.new()
  end

  defp get_prefix(nil, key), do: key
  defp get_prefix(prefix, key), do: "#{prefix}.#{key}"
  defp get_prefix(nil, key, index), do: "#{key}[#{index}]"
  defp get_prefix(prefix, key, index), do: "#{prefix}.#{key}[#{index}]"
end
