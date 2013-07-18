defmodule Eidetic.Query do

  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    Eidetic.TableInfo[name: name, fields: fields, pkey: pkey,
                      indicies: indicies] = Eidetic.TableInfo.for_module env.module

    match_spec = list_to_tuple([name | :lists.duplicate(Enum.count(fields), :_)])

    fields_index = Enum.with_index fields

    index_positions = Enum.map indicies, fn(index) ->
      Keyword.get(fields_index, index) + 2
    end

    quote location: :keep do

      def match_spec do
        unquote(Macro.escape match_spec)
      end

      def all do
        :mnesia.dirty_match_object unquote(Macro.escape match_spec)
      end

      def get(value) do
        items = :mnesia.dirty_read {unquote(name), value}
        case items do
          [item] -> item
          []     -> nil
        end
      end

      def get!(value) do
        case get(value) do
          nil  ->
            raise unquote(name).NotFound[message: "#{unquote(name)} with #{unquote(pkey)} = #{inspect value} not found"]
          item -> item
        end
      end

      defp find_index_for(spec) do
        Enum.reduce unquote(index_positions), nil, fn (pos, index) ->
          if index === nil and elem(spec, pos - 1) !== :_ do
            pos
          else
            index
          end
        end
      end

      def find(spec) do
        case find_index_for(spec) do
          nil -> :mnesia.dirty_match_object spec
          pos -> :mnesia.dirty_index_match_object spec, pos
        end
      end

      def find_by_index(spec, field) do
        :mnesia.dirty_index_match_object spec, Keyword.get(unquote(fields_index), field) + 2
      end

    end
  end

end