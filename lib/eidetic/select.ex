defmodule Eidetic.Select do

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
  @select_op :==

  @select_op_sub {:"===", :"=="}
  @select_op_sub {:"!=", :"=/="}
  @select_op_sub {:"!==", :"=/="}
  @select_op_sub {:<=, :"=<"}
  @select_op_sub {:and, :andalso}
  @select_op_sub {:or, :orelse}


  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end


  defmacro __before_compile__(env) do

    table_info = Eidetic.TableInfo.for_module env.module

    quote location: :keep do

      defmacro select(what, [do: code]) do
        Eidetic.Select.prepare_select __CALLER__, unquote(Macro.escape table_info), Macro.expand_all(what, __CALLER__), code
      end

      defmacro select([do: code]) do
        Eidetic.Select.prepare_select __CALLER__, unquote(Macro.escape table_info), :"$_", code
      end

      unquote_splicing(Enum.map Enum.with_index(table_info.fields), fn ({field, index}) ->

        quote location: :keep do
          defmacro unquote(field)() do
            unquote(:"$#{index + 1}")
          end
        end

      end)

    end
  end


  def prepare_select(env, table_info, what, code) do

    select_head = Enum.with_index(table_info.fields) |>
                    Enum.reduce([table_info.name], fn ({_, index}, head) ->
                      [:"$#{index + 1}" | head]
                    end) |> :lists.reverse |> list_to_tuple |> Macro.escape

    query = [transform(Macro.expand_all(code, env), true)] |> List.flatten

    if is_match_spec(query) do
      match_spec = query_to_matchspec(table_info, query)
      if what === :"$_"do
        quote do
          unquote(table_info.name).find(unquote(match_spec))
        end
      else
        field_pos_to_idx = Eidetic.Select.fields_to_positions_list table_info.fields
        return_idx = Keyword.get(field_pos_to_idx, what)
        quote do
          unquote(table_info.name).find(unquote(match_spec)) |> Enum.map(elem(&1, unquote(return_idx)))
        end
      end
    else
      quote do
        :mnesia.dirty_select unquote(table_info.name), [{unquote(select_head), unquote(query), [unquote(what)]}]
      end
    end
  end


  defp transform({:__block__, _, exprs}, _) do
    Enum.map(exprs, transform(&1, true)) |> List.flatten
  end

  defp transform({name, loc, args}, toplevel) when is_list(loc) and is_list(args) and is_atom(name) do
    if has_variable_reference(args) do
      cond do
        Keyword.has_key?(@select_op_sub, name) ->
          quote do
            {unquote_splicing([Keyword.get(@select_op_sub, name) | Enum.map(args, transform(&1, false))])}
          end
        Enum.member?(@select_op, name) ->
          quote do
            {unquote_splicing([name | Enum.map(args, transform(&1, false))])}
          end
        true ->
          raise "`#{Macro.to_string({name, loc, args})}` not allowed in query"
      end
    else
      if toplevel, do: raise "`#{Macro.to_string({name, loc, args})}` not allowed in query"
      {name, loc, args}
    end
  end

  defp transform(val, _), do: val


  def is_variable_reference(arg) when is_atom(arg) do
    Regex.match? %r/^\$\d+$/, to_binary(arg)
  end

  def is_variable_reference(_), do: false


  def has_variable_reference(arg) when is_list(arg) do
    Enum.any? arg, function(has_variable_reference/1)
  end

  def has_variable_reference(arg) when is_atom(arg) do
    is_variable_reference(arg)
  end

  def has_variable_reference({name, loc, args}) when is_atom(name) and is_list(loc) do
    has_variable_reference(args)
  end

  def has_variable_reference(_), do: false


  def is_match_spec(query) when is_list(query) do
    Enum.all? query, function(is_match_spec/1)
  end

  def is_match_spec({:"{}", [], [:==, left, right]}) do
    cond do
      is_variable_reference(left) and not has_variable_reference(right) -> true
      is_variable_reference(right) and not has_variable_reference(left) -> true
      true -> false
    end
  end

  def is_match_spec({:"{}", [], [:andalso, branch_a, branch_b]}) do
    is_match_spec(branch_a) and is_match_spec(branch_b)
  end

  def is_match_spec(_), do: false


  def collect_equality_matches(query) when is_list(query) do
    Enum.map(query, collect_equality_matches(&1)) |> List.flatten
  end

  def collect_equality_matches({:"{}", [], [:==, left, right]}) do
    cond do
      is_variable_reference(left) -> [{left, right}]
      is_variable_reference(right) -> [{right, left}]
    end
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
    spec = Enum.reduce(collect_equality_matches(query), name.match_spec, fn ({pos, value}, match_spec) ->
      idx = Keyword.get(field_pos_to_idx, pos)
      set_elem(match_spec, idx, value)
    end)
    quote do
      {unquote_splicing(tuple_to_list(spec))}
    end
  end

end
