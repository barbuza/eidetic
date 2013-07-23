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

    find_match_spec = list_to_tuple([name | :lists.duplicate(Enum.count(fields), {:_, [], __MODULE__})])

    index_find_defs = Enum.map [{pkey, 2} | List.zip([indicies, index_positions])], fn({index_name, index}) ->
      tuple_args = find_match_spec |> set_elem(index - 1, {index_name, [], __MODULE__}) |> tuple_to_list
      argument = {:=, [], [{:spec, [], __MODULE__}, {:"{}", [], tuple_args}]}
      {:def, [context: name],
        [{:when, [],
          [{:find, [], [argument]},
           {:!==, [context: __MODULE__, import: Kernel], [{index_name, [], __MODULE__}, :_]}]},
        [do: {{:., [], [:mnesia, :dirty_index_match_object]}, [], [{:spec, [], __MODULE__}, index]}]]}
    end

    find_def = {:def, [context: name],
                 [{:find, [],
                   [{:=, [], [{:spec, [], __MODULE__}, {:"{}", [], tuple_to_list(find_match_spec)}]}]},
                   [do: {{:., [], [:mnesia, :dirty_match_object]}, [], [{:spec, [], __MODULE__}]}]]}

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

      Enum.map unquote(Macro.escape index_find_defs), fn(find_def) ->
        Module.eval_quoted __ENV__, find_def
      end

      Module.eval_quoted __ENV__, unquote(find_def)

    end
  end

end
