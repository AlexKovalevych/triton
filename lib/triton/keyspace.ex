defmodule Triton.Keyspace do
  @moduledoc """
  Defines keyspace struct with __metadata__ key
  """

  alias Triton.Metadata

  defmacro __using__(_) do
    quote do
      import Triton.Keyspace
    end
  end

  defmacro keyspace(name, [conn: conn, pool: pool], do: block) do
    quote do
      Module.put_attribute(__MODULE__, :metadata, %Metadata{
        conn: unquote(conn),
        pool: unquote(pool),
        name: unquote(name),
        keyspace: []
      })

      unquote(block)

      defstruct __metadata__: Module.get_attribute(__MODULE__, :metadata)

      def metadata, do: @metadata
    end
  end

  defmacro with_options(opts) do
    quote do
      metadata = Module.get_attribute(__MODULE__, :metadata)
      keyspace = [{:__with_options__, unquote(opts)} | metadata.keyspace]
      Module.put_attribute(__MODULE__, :metadata, %{metadata | keyspace: keyspace})
    end
  end
end
