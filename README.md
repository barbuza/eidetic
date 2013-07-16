# Eidetic /aɪˈdɛtɪk/

alternate mnesia interface for `elixir`

# define
valid storage types are `memory`, `disk` and `memory_and_disk`

`validate` exposes value as field name

currently, only `non_empty_string/1` is custom validator available

`validate_presence_of` will check if `value !== nil`

    defrecord User, [id: nil, name: nil, email: nil, is_admin: false] do
      use Eidetic

      @index_on :is_admin
      @storage :memory

      validate_with :id, function(is_integer/1)

      validate :name do
        non_empty_string(name)
      end

      validate_presence_of :email

    end


# create schema
    User.Meta.create!

# create records
`create!` will check if not other records stored with given pkey value

    User.new! id: 1, name: "foo", email: "foo@gmail.com"
    User[id: 2, name: "spam", email: "spam@me.com", is_admin: true].create!

# make queries
eidetic will try to utilize first specified index in match spec

    User.get 1
    User.find User.match_spec.is_admin(true)

#alter data
`change_#{pkey}!` will check if not record is stored for new given value

`save!` will just invoke `:mnesia.write` with no uniq checks

    User.get(1).email("some_new_email@host.com").save!
    User.get(1).change_id!(2)
    User.get(2).delete!

all save / update methods will run validation before altering database