defmodule Eidetic do

  defmacro __using__(_) do
    quote location: :keep do
      Module.register_attribute __MODULE__, :index_on, accumulate: true
      Module.register_attribute __MODULE__, :storage, accumulate: false
      Module.register_attribute __MODULE__, :validate_presence_of, accumulate: true

      use Eidetic.Exceptions
      use Eidetic.Meta
      use Eidetic.Query
      use Eidetic.Validations
      use Eidetic.Update
      use Eidetic.Enumerable
    end
  end

end
