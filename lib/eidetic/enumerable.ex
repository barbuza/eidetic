defmodule Eidetic.Enumerable do

  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    Eidetic.TableInfo[name: name] = Eidetic.TableInfo.for_module env.module
    proxy_name = binary_to_atom(to_binary(name) <> ".EnumProxy")
    shortname = Regex.replace %r/^Elixir\./, to_binary(name), ""
    enum = {proxy_name, nil}
    quote do

      defrecord EnumProxy, [:dummy]

      def enum, do: unquote(enum)

      defimpl Enumerable, for: unquote(proxy_name) do

        def count(unquote(enum)) do
          :mnesia.table_info unquote(name), :size
        end

        def member?(unquote(enum), value) do
          unquote(name).get(elem(value, 1)) === value
        end

        def reduce(unquote(enum), acc, fun) do
          {:atomic, result} = :mnesia.transaction fn ->
            :mnesia.foldl fun, acc, unquote(name)
          end
          result
        end

      end

      defimpl Inspect, for: unquote(proxy_name) do

        def inspect(val, opts) do
          "##{unquote(shortname)}.Enumerable"
        end

      end

    end
  end
end
