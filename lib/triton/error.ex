defmodule Triton.Error do
  defstruct message: ""

  def invalid_cql_operation do
    %Triton.Error{
      message: "Invalid CQL operation.  Must be one of SELECT, INSERT, UPDATE, or DELETE"
    }
  end

  def vex_error(errors) when is_list(errors) do
    Enum.map(errors, fn {:error, field, _, message} ->
      %{message: "Invalid input. #{field} #{message}.", path: to_string(field)}
    end)
  end

  def vex_error(_), do: %Triton.Error{message: "Invalid input."}
end
