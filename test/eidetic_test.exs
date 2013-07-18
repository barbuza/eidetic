Code.require_file "test_helper.exs", __DIR__
:application.start :mnesia


defrecord User, [id: nil, name: nil, email: nil, is_admin: false, perms: []] do
  use Eidetic

  @index_on :is_admin
  @storage :memory

  validate_with :perms, function(is_list/1)

  validate_with :id, function(is_integer/1)

  validate :name do
    non_empty_string(name)
  end

  validate_presence_of :email

end


defmodule EideticTest do
  use ExUnit.Case
  require User

  defp create_test_users do
    names = %w(foo bar spam eggs)
    hosts = %w(gmail.com me.com)
    Enum.each 1..1000, fn (id) ->
      name = Enum.at names, rem(id, 4)
      host = Enum.at hosts, rem(id, 2)
      email = name <> "@" <> host
      is_admin = id === 500
      User.new! id: id, name: name, email: email, is_admin: is_admin
    end
  end

  setup do
    User.Meta.create!
  end

  teardown do
    User.Meta.delete!
  end

  test "inspect" do
    assert inspect(User[]) === "#User<[id: nil, name: nil, email: nil, is_admin: false, perms: []]>"
    assert inspect(User.enum) === "#User.Enumerable"
  end

  test "validations" do
    assert_raise User.ValidationError, "nil is not valid value for id", fn ->
      User.new! []
    end
    assert_raise User.ValidationError, "\"foo\" is not valid value for id", fn ->
      User[id: "foo"].save!
    end
    assert_raise User.ValidationError, "\"\" is not valid value for name", fn ->
      User[id: 10, name: ""].create!
    end
    assert_raise User.ValidationError, "nil is not valid value for email", fn ->
      User[id: 10, name: "foo"].create!
    end    
  end

  test "meta" do
    assert [:id, :name, :email, :is_admin, :perms] === User.Meta.fields
    assert [:is_admin] === User.Meta.indicies
    assert :memory === User.Meta.storage
    assert_raise User.TableAlreadyExists, fn ->
      User.Meta.create!
    end
    assert :ok === User.Meta.delete!
    assert_raise User.TableDoesNotExist, fn ->
      User.Meta.delete!
    end
    assert :ok === User.Meta.create!
  end

  test "queries" do
    create_test_users
    assert_raise User.NotFound, fn ->
      IO.inspect User.get! 1001
    end
    assert User[id: 10, name: "spam", email: "spam@gmail.com", is_admin: false] === User.get(10)
    assert [User[id: 500, name: "foo", email: "foo@gmail.com", is_admin: true]] === User.find(User.match_spec.is_admin(true))
    assert 250 === length(User.find User.match_spec.name("eggs"))
  end

  test "updates" do
    User[id: 1, name: "spam", email: "spam@gmail.com"].create!
    assert_raise User.NonUniq, fn ->
      User[id: 1, name: "spam", email: "spam@gmail.com"].create!
    end
    User[id: 1, name: "spam", email: "spam@gmail.com"].save!
    user = User.get 1
    user.change_id! 2
    assert nil === User.get 1
    assert user.id(2) === User.get 2
    User[id: 1, name: "eggs", email: "eggs@me.com"].create!
    assert_raise User.NonUniq, fn ->
      user = User.get 1
      user.change_id! 2
    end
  end

  test "enum" do
    create_test_users
    assert Enum.reduce(User.enum, 0, fn (_, count) -> count + 1 end) === 1000
    assert Enum.count(User.enum) === 1000
    assert Enum.member?(User.enum, User[id: 1]) === false
    assert Enum.member?(User.enum, User.get(1)) === true
  end

  test "select" do
    create_test_users

    assert [10, 20] === Enum.sort(User.select User.id do
      (User.id == 10) or (User.id == 20)
    end)

    res = User.select do
      User.id < 50
      User.email == "foo@gmail.com"
    end
    assert Enum.map(1..12, &1 * 4) == Enum.map(Enum.sort(res), elem(&1, 1))
    
    assert [1] == (User.select User.id do
      User.id == 1
      User.is_admin == false
    end)

    id = 10
    assert [User.get(10)] == (User.select do
      hd([id]) == User.id
    end)

    User.get(30).perms([:editor]).save!
    assert [User.get(10), User.get(30)] == Enum.sort(User.select do
      User.id == hd([id]) or hd(User.perms) == :editor
    end)

  end
end
