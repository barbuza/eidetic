# Eidetic /aɪˈdɛtɪk/ [![Build Status](https://travis-ci.org/barbuza/eidetic.png)](https://travis-ci.org/barbuza/eidetic)

alternate mnesia interface for `elixir`


### define
```elixir
defrecord User, [id: nil, name: nil, email: nil, is_admin: false, perms: []] do
  use Eidetic

  validate_with :perms, function(is_list/1)

  @index_on :is_admin
  @storage :memory

  validate_with :id, function(is_integer/1)

  validate :name do
    non_empty_string(name)
  end

  validate_presence_of :email

end
```
valid storage types are `memory`, `disk` and `memory_and_disk`

`validate` exposes value as field name

currently, only `non_empty_string/1` is custom validator available

`validate_presence_of` will check if `value !== nil`


### create schema
```elixir
User.Meta.create!
```

### create records
```elixir
User.new! id: 1, name: "foo", email: "foo@gmail.com"
User[id: 2, name: "spam", email: "spam@me.com", is_admin: true].create!
```

`create!` and `new!` will check if no other records stored with given pkey value


### make queries
```elixir
User.get 1
User.find User.match_spec.is_admin(true)
```

eidetic will try to utilize first specified index in match spec


###alter data

```elixir
User.get(1).email("some_new_email@host.com").save!
User.get(1).change_id!(2)
User.get(2).delete!
```

`change_#{pkey}!` will check if no record is stored for a pk given value, it will also validate new given value

`save!` will just invoke `:mnesia.write` with no uniq checks

###use `:mnesia.select` with no pain in the ass
```elixir
require User

User.select do
  (User.id == 10) or (User.id == 20)
end

User.select User.id do
  User.is_admin == true
  User.id < 1000
end

User.select do
  hd(User.perms) == :editor
end
```

look at `lib/eidetic/select.ex` for list of functions / operators available

`select` will try to use `find` if possible (if there are only equality checks)
