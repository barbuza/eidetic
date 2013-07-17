defmodule Eidetic.Enumerable do

  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    Eidetic.TableInfo[name: name, fields: fields] = Eidetic.TableInfo.for_module env.module
    enum = Macro.escape list_to_tuple([name | :lists.duplicate(Enum.count(fields), :__enum)])
    quote do

      def enum, do: unquote(enum)

      defimpl Enumerable, for: unquote(name) do

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
    end
  end
end
