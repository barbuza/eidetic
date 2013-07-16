defrecord Eidetic.TableInfo, [:name, :pkey, :rest_fields, :fields, :indicies, :storage] do

  def for_module(module) do
    indicies = Module.get_attribute module, :index_on
    fields = List.unzip(Module.get_attribute module, :record_fields) |> Enum.first
    storage = case Module.get_attribute(module, :storage) do
      nil -> :memory_and_disk
      value -> value
    end
    pkey = Enum.first fields
    rest_fields = Enum.drop fields, 1
    new name: module, pkey: pkey, rest_fields: rest_fields, fields: fields, indicies: indicies, storage: storage
  end

end
