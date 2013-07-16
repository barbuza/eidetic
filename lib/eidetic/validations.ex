defmodule Eidetic.Validations do
  
  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
      import unquote(__MODULE__), only: [non_empty_string: 1]
      import :macros, unquote(__MODULE__), only: [validate: 2, validate_with: 2, validate_presence_of: 1]
    end
  end

  def non_empty_string(value) do
    is_bitstring(value) and size(value) > 0
  end

  defmacro validate_presence_of(field) do
    quote do
      def validate_field(unquote(field), value) do
        value !== nil
      end
    end
  end

  defmacro validate(field, [do: code]) do
    quote do
      def validate_field(unquote(field), value) do
        var!(unquote(field)) = value
        unquote(code)
      end
    end
  end

  defmacro validate_with(field, fun) do
    quote do
      def validate_field(unquote(field), value) do
        unquote(fun).(value)
      end
    end
  end


  defmacro __before_compile__(env) do
    Eidetic.TableInfo[name: name, fields: fields] = Eidetic.TableInfo.for_module env.module
    quote location: :keep do

      def validate_field(_, _) do
        true
      end

      def validate!(value) do
        Enum.each unquote(Enum.with_index(fields)), fn ({field, index}) ->
          field_value = elem(value, index + 1)
          if not validate_field(field, field_value) do
            raise unquote(:"#{name}.ValidationError")[field: field, value: field_value]
          end
        end 
      end

    end
  end

end