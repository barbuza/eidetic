defmodule Eidetic.Meta do

  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    Eidetic.TableInfo[name: name, fields: fields, indicies: indicies,
                      storage: storage] = Eidetic.TableInfo.for_module env.module
    quote location: :keep do
      defmodule Meta do

        def fields, do: unquote(fields)

        def indicies, do: unquote(indicies)

        def storage, do: unquote(storage)

        def create!(nodes // nil) do
          if nodes == nil, do: nodes = [node]
          index_positions = Enum.map indicies, fn (name) ->
            Keyword.get(Enum.with_index(fields), name) + 2
          end
          options = [
            attributes: fields,
            type: :set,
            index: index_positions
          ]
          options = [{copy_type, nodes} | options]
          case :mnesia.create_table(unquote(name), options) do
            {:atomic, :ok} -> :ok
            {:aborted, {:already_exists, unquote(name)}} ->
              raise unquote(:"#{name}.TableAlreadyExists")[]
          end
        end

        def delete! do
          case :mnesia.delete_table unquote(name) do
            {:atomic, :ok} -> :ok
            {:aborted, {:no_exists, unquote(name)}} ->
              raise unquote(:"#{name}.TableDoesNotExist")[]
          end
        end

        def add_copy!(copy_to) do
          case :mnesia.add_table_copy(unquote(name), copy_to, copy_type) do
            {:atomic, :ok} -> :ok
            {:aborted, {:already_exists, unquote(name), copy_to}} ->
              raise unquote(:"#{name}.TableAlreadyExists")[message: "table #{unquote(name)} already exists at #{copy_to}"]
          end
        end

        defp copy_type do
          case storage do
            :disk -> :disc_only_copies
            :memory -> :ram_copies
            :memory_and_disk -> :disc_copies
          end
        end

      end
    end
  end

end