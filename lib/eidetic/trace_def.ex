defmodule Eidetic.TraceDef do

  def __on_definition__(env, kind, name, args, _guards, _body) do
    args_list = Enum.reduce args, nil, fn (arg, lst) ->
      case lst do
        nil -> ""
        _ -> lst <> ", "
      end <> case arg do
        [do: _] -> "do..."
        {://, _, [{name, _, _}, default]} -> to_binary(name) <> " // " <> Kernel.inspect(default)
        {name, _, _} -> to_binary name
        _ -> Kernel.inspect arg
      end
    end
    IO.puts "#{inspect env.module}.#{kind} #{name}(#{args_list})"
  end

end
