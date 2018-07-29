defmodule Triton.QueryBuilder do
  def build_query(type, module, value) do
    quote do
      [
        {unquote(type), unquote(value)}
        | Triton.QueryBuilder.query_list(unquote(module))
      ]
    end
  end

  def query_list(module) when is_list(module), do: module

  def query_list(module) do
    [
      {:__metadata__, module.metadata()}
    ]
  end
end
