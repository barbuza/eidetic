defmodule Eidetic.Exceptions do

  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    Eidetic.TableInfo[name: name] = Eidetic.TableInfo.for_module env.module
    quote location: :keep do

      defexception NonUniq, [:message]
      
      defexception NotFound, [:message]
      
      defexception TableDoesNotExist, [message: "table #{unquote(name)} does not exist"]
      
      defexception TableAlreadyExists, [message: "table #{unquote(name)} already exists"]
      
      defexception ValidationError, [:field, :value] do

        def message(error) do
          "#{inspect error.value} is not valid value for #{error.field}"
        end

      end
    end
  end

end
