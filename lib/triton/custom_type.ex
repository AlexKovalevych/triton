defmodule Triton.CustomType do
  defmacro __using__(_) do
    quote do
      import Triton.CustomType
      use Triton.Executor
    end
  end

  defmacro custom_type(name, [keyspace: keyspace], do: block) do
    quote do
      outer = __MODULE__

      defmodule Metadata do
        @metadata []

        Module.put_attribute(__MODULE__, :metadata, [
          {:__custom_type__, unquote(name)},
          {:__schema_module__, outer}
        ])

        defstruct Module.get_attribute(__MODULE__, :metadata)
      end

      defmodule CustomType do
        @after_compile __MODULE__

        @custom_type []
        @fields %{}

        unquote(block)

        Module.put_attribute(__MODULE__, :custom_type, [
          {:__keyspace__, unquote(keyspace)},
          {:__name__, unquote(name)},
          {:__fields__, Module.get_attribute(__MODULE__, :fields)}
          | Module.get_attribute(__MODULE__, :custom_type)
        ])

        def __after_compile__(_, _), do: Triton.Setup.CustomType.setup(__MODULE__.__struct__())

        defstruct Module.get_attribute(__MODULE__, :custom_type)
      end
    end
  end

  defmacro field(name, type, opts \\ []) do
    quote do
      fields =
        Module.get_attribute(__MODULE__, :fields)
        |> Map.put(unquote(name), %{
          type: unquote(type),
          opts: unquote(opts)
        })

      Module.put_attribute(__MODULE__, :fields, fields)
    end
  end
end
