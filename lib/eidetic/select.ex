defmodule Eidetic.Select do

  defmacro __using__(_) do
    quote do

      Module.register_attribute __MODULE__, :select_op, accumulate: true
      Module.register_attribute __MODULE__, :select_op_sub, accumulate: true

      @select_op :is_atom
      @select_op :is_float
      @select_op :is_integer
      @select_op :is_list
      @select_op :is_number
      @select_op :is_pid
      @select_op :is_port
      @select_op :is_reference
      @select_op :is_tuple
      @select_op :is_binary
      @select_op :is_function
      @select_op :is_record
      @select_op :abs
      @select_op :element
      @select_op :hd
      @select_op :length
      @select_op :round
      @select_op :size
      @select_op :tl
      @select_op :trunc
      @select_op :+
      @select_op :-
      @select_op :*
      @select_op :div
      @select_op :rem
      @select_op :band
      @select_op :bor
      @select_op :bxor
      @select_op :bnot
      @select_op :bsl
      @select_op :bsr
      @select_op :>
      @select_op :<
      @select_op :>=

      @select_op_sub {:"==", :"=:="}
      @select_op_sub {:"===", :"=:="}
      @select_op_sub {:"!=", :"=/="}
      @select_op_sub {:"!==", :"=/="}
      @select_op_sub {:<=, :"=<"}
      @select_op_sub {:and, :andalso}
      @select_op_sub {:or, :orelse}

      @before_compile unquote(__MODULE__)

    end
  end

  defmacro __before_compile__(env) do

    table_info = Eidetic.TableInfo.for_module env.module
    Eidetic.TableInfo[name: name, fields: fields] = table_info

    select_head = Enum.with_index(fields) |>
                  Enum.reduce([name], fn ({_, index}, head) ->
                    [:"$#{index + 1}" | head]
                  end) |>
                  :lists.reverse |>
                  list_to_tuple |>
                  Macro.escape

    quote location: :keep do

      defmacro select(what, [do: code]) do
        __select_prepare_select __CALLER__, Macro.expand_all(what, __CALLER__), code
      end

      defmacro select([do: code]) do
        __select_prepare_select __CALLER__, :"$_", code
      end

      defp __select_prepare_select(env, what, code) do
        query = Macro.expand_all (__select_prepare_query code), env
        select_head = unquote(Macro.escape select_head)
        name = unquote(name)
        if Eidetic.Select.is_match_spec? query do
          match_spec = Eidetic.Select.query_to_matchspec unquote(Macro.escape table_info), query
          if what === :"$_"do
            quote do
              unquote(name).find(unquote(Macro.escape match_spec))
            end
          else
            field_pos_to_idx = Eidetic.Select.fields_to_positions_list unquote(fields)
            return_idx = Keyword.get(field_pos_to_idx, what)
            quote do
              Enum.map unquote(name).find(unquote(Macro.escape match_spec)), elem(&1, unquote(return_idx))
            end
          end
        else
          quote do
            :mnesia.dirty_select unquote(name), [{unquote(select_head), unquote(query), [unquote(what)]}]
          end
        end
      end

      defp __select_prepare_query(code) do
        query = __select_transform code
        List.flatten [query]
      end

      defp __select_transform({:__block__, _, exprs}) do
        Enum.map exprs, __select_transform(&1)
      end

      defp __select_transform({name, loc, args}) when is_list(loc) and is_list(args) and is_atom(name) do
        cond do
          Keyword.has_key?(@select_op_sub, name) ->
            quote do
              {unquote_splicing([Keyword.get(@select_op_sub, name) | Enum.map(args, __select_transform(&1))])}
            end
          Enum.member?(@select_op, name) ->
            quote do
              {unquote_splicing([name | Enum.map(args, __select_transform(&1))])}
            end
          true ->
            {name, loc, args}
        end
      end

      defp __select_transform(val), do: val

      unquote_splicing(Enum.map Enum.with_index(fields), fn ({field, index}) ->

        quote location: :keep do
          defmacro unquote(field)() do
            unquote(:"$#{index + 1}")
          end
        end

      end)

    end
  end


  def is_match_spec?(query) when is_list(query) do
    Enum.all?(query, is_match_spec?(&1))
  end

  def is_match_spec?({:andalso, [], args}) do
    Enum.all? args, is_match_spec?(&1)
  end

  def is_match_spec?({:"{}", [], [:andalso, branch_a, branch_b]}) do
    is_match_spec?(branch_a) and is_match_spec?(branch_b)
  end

  def is_match_spec?({:"{}", [], [:"=:=", field, value]})
  when is_atom(field) and (is_binary(value) or is_list(value) or is_number(value) or is_atom(value)) do
    true
  end

  def is_match_spec?(_), do: false

  def collect_equality_matches(query) when is_list(query) do
    List.flatten Enum.map(query, collect_equality_matches(&1))
  end

  def collect_equality_matches({:"{}", [], [:"=:=", field, value]}) do
    [{field, value}]
  end

  def collect_equality_matches({:"{}", [], [:andalso, branch_a, branch_b]}) do
    [collect_equality_matches(branch_a), collect_equality_matches(branch_b)]
  end

  def fields_to_positions_list(fields) do
    Enum.with_index(fields) |>
      Enum.reduce([], fn ({_, index}, head) ->
        [{:"$#{index + 1}", index + 1} | head]
      end)
  end

  def query_to_matchspec(Eidetic.TableInfo[name: name, fields: fields], query) do
    field_pos_to_idx = fields_to_positions_list fields
    Enum.reduce collect_equality_matches(query), name.match_spec, fn ({pos, value}, match_spec) ->
      idx = Keyword.get(field_pos_to_idx, pos)
      set_elem(match_spec, idx, value)
    end
  end

end
