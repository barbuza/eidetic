defmodule Eidetic.Select do

  defexception QueryError, [:code, :line] do
    def message(err), do: "`#{Macro.to_string(err.code)}` not allowed in Eidetic#select"  
  end

  Module.register_attribute __MODULE__, :select_ops, accumulate: false
  Module.register_attribute __MODULE__, :select_op_sub, accumulate: true


  @select_ops [:is_atom, :is_float, :is_integer, :is_list, :is_number, :is_pid,
               :is_port, :is_reference, :is_tuple, :is_binary, :is_function,
               :is_record, :abs, :element, :hd, :length, :round, :size, :tl,
               :trunc, :+, :-, :*, :div, :rem, :band, :bor, :bxor, :bnot, :bsl,
               :bsr, :>, :<, :>=, :==]


  @select_op_sub {:===, :==}
  @select_op_sub {:!=, :"=/="}
  @select_op_sub {:!==, :"=/="}
  @select_op_sub {:<=, :"=<"}
  @select_op_sub {:and, :andalso}
  @select_op_sub {:or, :orelse}


  defmacro __using__(_) do

      quote location: :keep do

        defmacro table_info, do: Macro.escape Eidetic.TableInfo.for_module __MODULE__

        defmacro select(what, [do: code]) do
          Eidetic.Select.prepare_select __CALLER__, table_info, Macro.expand_all(what, __CALLER__), code
        end

        defmacro select([do: code]) do
          Eidetic.Select.prepare_select __CALLER__, table_info, :"$_", code
        end

        Enum.each Enum.with_index(@record_fields), fn ({{field, _}, index}) ->
          Module.eval_quoted(__ENV__, quote location: :keep do
            defmacro unquote(field)() do
              unquote(:"$#{index + 1}")
            end
          end)
        end

    end
  end


  def prepare_select(env, table_info, what, code) do

    select_head = Enum.with_index(table_info.fields) |>
                    Enum.reduce([table_info.name], fn ({_, index}, head) ->
                      [:"$#{index + 1}" | head]
                    end) |> :lists.reverse |> list_to_tuple |> Macro.escape

    try do
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

    rescue
      err in [QueryError] ->
        raise CompileError[description: err.message, line: err.line, file: env.file]
    end

  end


  defp transform({:__block__, _, exprs}, _) do
    Enum.map(exprs, transform(&1, true)) |> List.flatten
  end

  defp transform({:startswith, loc, [data, field]}, _) when is_list(loc) and is_atom(field) and is_binary(data) do
    lastchar = :binary.last data
    prefix = :binary.part data, 0, size(data) - 1
    quote do
      {:andalso,
        {:>, unquote(field), unquote(<< prefix :: binary, lastchar - 1 >>)},
        {:<, unquote(field), unquote(<< prefix :: binary, lastchar + 1 >>)}}
    end
  end

  defp transform({:startswith, loc, [data, field]}, _) when is_list(loc) and is_atom(field) do
    prefix = quote do
      :binary.part unquote(data), 0, size(unquote(data)) - 1
    end
    lastchar = quote do
      :binary.last unquote(data)
    end
    quote do
      {:andalso,
        {:>, unquote(field), << (unquote(prefix)) :: binary, (unquote(lastchar) - 1) >>},
        {:<, unquote(field), << (unquote(prefix)) :: binary, (unquote(lastchar) + 1) >>}}
    end
  end

  defp transform({name, loc, args}, toplevel) when is_list(loc) and is_list(args) and is_atom(name) do
    if has_variable_reference(args) do
      cond do
        Keyword.has_key?(@select_op_sub, name) ->
          quote do
            {unquote_splicing([Keyword.get(@select_op_sub, name) | Enum.map(args, transform(&1, false))])}
          end
        Enum.member?(@select_ops, name) ->
          quote do
            {unquote_splicing([name | Enum.map(args, transform(&1, false))])}
          end
        true ->
          raise QueryError[code: {name, loc, args}, line: Keyword.get(loc, :line, :undef)]
      end
    else
      if toplevel do
        raise QueryError[code: {name, loc, args}, line: Keyword.get(loc, :line, :undef)]
      end
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
    match_spec = list_to_tuple([name | :lists.duplicate(Enum.count(fields), :_)])
    field_pos_to_idx = fields_to_positions_list fields
    spec = Enum.reduce(collect_equality_matches(query), match_spec, fn ({pos, value}, mspec) ->
      idx = Keyword.get(field_pos_to_idx, pos)
      set_elem(mspec, idx, value)
    end)
    quote do
      {unquote_splicing(tuple_to_list(spec))}
    end
  end
end
