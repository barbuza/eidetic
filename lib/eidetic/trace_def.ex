defmodule Eidetic.TraceDef do

  def arg_to_display([do: _]), do: "do..."

  def arg_to_display([]), do: ""

  def arg_to_display(list) when is_list(list) do
    Enum.reduce list, nil, fn (arg, lst) ->
      case lst do
        nil -> ""
        _ -> lst <> ", "
      end <> arg_to_display(arg)
    end
  end

  def arg_to_display({:=, _, [left, right]}) do
    arg_to_display(left) <> "=" <> arg_to_display(right)
  end

  def arg_to_display({://, _, [{name, _, _}, default]}) do
    to_binary(name) <> " // " <> Kernel.inspect(default)
  end

  def arg_to_display({:"{}", _, args}) do
    "{" <> arg_to_display(args) <> "}"
  end

  def arg_to_display({name, _, _}) do
    to_binary name
  end

  def arg_to_display(arg), do: Kernel.inspect arg

  def guard_to_display({op, _, [left, right]})
  when op == :"!==" or op == :"!===" or op == :"==" or op == :"===" do
    arg_to_display(left) <> " " <> to_binary(op) <> " " <> arg_to_display(right)
  end

  def guard_to_display({op, _, [left, right]})
  when op == :or or op == :and do
    "(" <> guard_to_display(left) <> " " <> to_binary(op) <> " " <> guard_to_display(right) <> ")"
  end

  def guard_to_display({fun, _, [arg]}) do
    to_binary(fun) <> "(" <> arg_to_display(arg) <> ")"
  end

  def __on_definition__(env, kind, name, args, guards, _body) do
    guards_repr = ""
    if Enum.count(guards) > 0 do
      guards_repr = Enum.reduce guards, nil, fn (guard, lst) ->
        case lst do
          nil -> " when "
          _ -> lst <> ", "
        end <> guard_to_display(guard)
      end
    end
    args_repr = arg_to_display args
    if size(args_repr) > 0 do
      args_repr = "(" <> args_repr <> ")"
    end
    IO.puts "#{inspect env.module}.#{kind} #{name}#{args_repr}#{guards_repr}"
  end

end
