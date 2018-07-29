defmodule Triton.Schema do
  @moduledoc false

  alias Triton.Metadata

  defmacro __using__(_) do
    quote do
      import Triton.Schema
      use Triton.Executor
    end
  end

  defmacro table(name, [keyspace: keyspace], do: block) do
    quote do
      Module.put_attribute(__MODULE__, :metadata, %Metadata{
        table: [],
        keyspace: unquote(keyspace),
        name: unquote(name),
        fields: %{},
        conn: unquote(keyspace).metadata().conn,
        pool: unquote(keyspace).metadata().pool
      })

      unquote(block)

      fields =
        Enum.into(Module.get_attribute(__MODULE__, :metadata).fields, [], fn {k, v} ->
          {k, nil}
        end)

      defstruct Keyword.put(fields, :__metadata__, Module.get_attribute(__MODULE__, :metadata))
      def metadata, do: @metadata
    end
  end

  defmacro type(name, [keyspace: keyspace], do: block) do
    quote do
      Module.put_attribute(__MODULE__, :metadata, %Metadata{
        keyspace: unquote(keyspace),
        name: unquote(name),
        fields: %{}
      })

      unquote(block)

      fields =
        Enum.into(Module.get_attribute(__MODULE__, :metadata).fields, [], fn {k, v} ->
          {k, nil}
        end)

      defstruct Keyword.put(fields, :__metadata__, Module.get_attribute(__MODULE__, :metadata))
    end
  end

  defmacro materialized_view(name, [from: from], do: block) do
    quote do
      Module.put_attribute(__MODULE__, :metadata, %Metadata{
        table: [],
        from: unquote(from),
        keyspace: unquote(from).metadata.keyspace,
        name: unquote(name),
        fields: %{}
      })

      unquote(block)

      defstruct __metadata__: Module.get_attribute(__MODULE__, :metadata)
    end
  end

  defmacro field(name, type, opts \\ []) do
    quote do
      metadata = Module.get_attribute(__MODULE__, :metadata)

      fields =
        Map.put(metadata.fields, unquote(name), %{
          type: unquote(type),
          opts: unquote(opts)
        })

      Module.put_attribute(__MODULE__, :metadata, %{metadata | fields: fields})
    end
  end

  defmacro fields(fields) do
    quote do
      metadata = Module.get_attribute(__MODULE__, :metadata)
      Module.put_attribute(__MODULE__, :metadata, %{metadata | fields: unquote(fields)})
    end
  end

  defmacro partition_key(keys) do
    quote do
      metadata = Module.get_attribute(__MODULE__, :metadata)
      table = [{:__partition_key__, unquote(keys)} | metadata.table]
      Module.put_attribute(__MODULE__, :metadata, %{metadata | table: table})
    end
  end

  defmacro cluster_columns(cols) do
    quote do
      metadata = Module.get_attribute(__MODULE__, :metadata)
      table = [{:__cluster_columns__, unquote(cols)} | metadata.table]
      Module.put_attribute(__MODULE__, :metadata, %{metadata | table: table})
    end
  end

  defmacro with_options(opts \\ []) do
    quote do
      metadata = Module.get_attribute(__MODULE__, :metadata)
      table = [{:__with_options__, unquote(opts)} | metadata.table]
      Module.put_attribute(__MODULE__, :metadata, %{metadata | table: table})
    end
  end
end
