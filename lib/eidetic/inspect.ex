defmodule Eidetic.Inspect do

  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    Eidetic.TableInfo[name: name, fields: fields] = Eidetic.TableInfo.for_module env.module
    shortname = Regex.replace %r/^Elixir\./, to_binary(name), ""
    quote do

      defimpl Inspect, for: unquote(name) do
        import Inspect.Algebra

        def inspect(val, opts) do
          fields = Enum.map(Enum.with_index(unquote(fields)), fn ({field, index}) ->
            ["#{field}: ", Kernel.inspect(elem(val, index + 1), opts)] ++ if index == length(unquote(fields)) - 1 do [] else [", "] end
          end) |> List.concat |> concat
          concat ["##{unquote(shortname)}<[", fields ,"]>"]
        end
      end

    end
  end
end
