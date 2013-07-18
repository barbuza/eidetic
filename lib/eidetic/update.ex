defmodule Eidetic.Update do
  
  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    Eidetic.TableInfo[name: name, pkey: pkey] = Eidetic.TableInfo.for_module env.module
    quote location: :keep do

      def unquote(:"change_#{pkey}!")(pk, value) do
        unquote(name).validate_field! unquote(pkey), pk
        value.validate!
        {:atomic, result} = :mnesia.transaction fn ->
          case :mnesia.read({unquote(name), pk}) do
            [_] ->
              unquote(name).NonUniq[message: "#{unquote(name)} with #{unquote(pkey)} = #{inspect pk} already exists"]
            [] ->
              :mnesia.delete {unquote(name), elem(value, 1)}
              value = set_elem value, 1, pk
              :mnesia.write value
              value
          end
        end
        case result do
          error = unquote(name).NonUniq[] -> raise error
          value = unquote(name)[] -> value
        end
      end

      def save!(value) do
        value.validate!
        :mnesia.dirty_write value
      end

      def new!(args) do
        unquote(name).new(args).create!
      end

      def create!(value) do
        value.validate!
        res = :mnesia.transaction fn ->
          case :mnesia.read({unquote(name), elem(value, 1)}) do
            [_] ->
              unquote(name).NonUniq[message: "#{unquote(name)} with #{unquote(pkey)} = #{inspect elem(value, 1)} already exists"]
            [] ->
              :ok = :mnesia.write(value)
          end
        end
        case res do
          {:atomic, :ok} -> :ok
          {:atomic, val=unquote(name).NonUniq[]} -> raise val
        end
      end

      def delete!(value) do
        :ok = :mnesia.dirty_delete {unquote(name), elem(value, 1)}
      end

    end
  end
end