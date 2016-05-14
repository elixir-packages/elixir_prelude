defmodule Prelude.Map do
  @moduledoc "Functions operating on `maps`."

  @doc """
  Group a map by an array of keys

  Provide a list of maps, and a list of keys to group by. All maps must
  have all the group_by fields, other fields can vary.

  For example:

      iex> Prelude.Map.group_by(
      ...>  [%{name: "stian", group: 1, cat: 2},
      ...>   %{name: "per",   group: 1, cat: 1}],
      ...>  [:group, :cat])
      %{1 =>
        %{1 => [%{cat: 1, group: 1, name: "per"}],
          2 => [%{cat: 2, group: 1, name: "stian"}] } }
  """
  def group_by(maps, groups) when is_list(maps) and is_list(groups) do
    Enum.reduce(maps, %{}, fn(x, acc)->
      extract_and_put(acc, x, groups)
    end)
  end

  defp extract_and_put(map, item, groups) do
    path = Enum.map(groups, fn(group)-> Map.get(item, group) end)
    deep_put(map, path, [item])
  end

  @doc """
  Put an arbitrarily deep key into an existing map.
  Works also with Stucts.

  If you want to create lists as values, provide :list as last parameter.

  If a value already exists at that level, it is turned into a list

  For example:
      # it works as expected with empty maps
      iex> Prelude.Map.deep_put(%{}, [:a, :b, :c], "0")
      %{a: %{b: %{c: "0"}}}

      # when provided a deep path, all intermediate items are converted to maps
      # this can lead to loss of data, eg:
      # a.b.c = 1 is replaced by a map to make path a.b.c.d = 2 possible
      iex> Prelude.Map.deep_put(%{a: %{b: %{c: "1"}}}, [:a, :b, :c, :d], "2")
      %{a: %{b: %{c: %{d: "2"}}}}

      # to collect values in a list, provide :list as last parameter.
      iex> Prelude.Map.deep_put(%{a: %{b: %{c: "1"}}}, [:a, :b, :c, :d], "2", :list)
      %{a: %{b: %{c: %{d: ["2"]}}}}

      # to collect values in a list, provide :list as last parameter.
      iex> Prelude.Map.deep_put(%{a: %{b: %{c: ["1"]}}}, [:a, :b, :c], "2", :list)
      %{a: %{b: %{c: ["2", "1"]}}}
  """
  def deep_put(map, path, val, variation \\ :map)
  def deep_put(map=%{__struct__: struct}, path, val, variation) do
    map
    |> Map.from_struct
    |> deep_put(path, val, variation)
    |> Map.put(:__struct__, struct)
  end


  def deep_put(map, path, val, variation) do
    state = {map, []}
    res = Enum.reduce(path, state, fn(x, {acc, cursor})->
      cursor   = [ x | cursor ]
      final    = length(cursor) == length(path)
      curr_val = get_in(acc, Enum.reverse(cursor))
      newval   = new_value(variation, curr_val, val, final)
      acc      = put_in(acc, Enum.reverse(cursor), newval)
      { acc, cursor }
    end)
    res |> elem(0)
  end

  defp new_value(:map, curr_val, val, final) do
    case curr_val do
      h = %{} -> if final, do: val, else: h
      _       -> if final, do: val, else: %{} # override non-map value!
    end
  end

  defp new_value(:list, curr_val, val, final) do
    case curr_val do
      h when is_list(h) -> [ val | h ]
      nil               -> if final, do: [val],    else: %{}
      h = %{}           -> if final, do: [val, h], else: h
      h                 -> if final, do: [val, h], else: %{} # overrided non-map values!
    end
  end

  @doc """
  To keep the API consistent also a way to get deep nested values.
  Works also with Stucts.

  """
  def deep_get(map=%{__struct__: _type}, path) do
    map
    |> Map.from_struct
    |> get_in(path)
  end
  def deep_get(map, path),  do: get_in(map, path)

  @doc """
  Remove a map key arbitrarily deep in a structure, similar to put_in
  Works also with Stucts.

  For example:

      iex> a = %{a: %{b: %{c: %{d: 1, e: 1}}}}
      ...> Prelude.Map.del_in(a, [:a, :b, :c, :d])
      %{a: %{b: %{c: %{e: 1}}}}
  """
  def del_in(map=%{__struct__: type}, path) do
    map
    |> Map.from_struct
    |> del_in(path)
    |> Map.put(:__struct__, type)
  end

  def del_in(map, path) do
    [item | path] = path |> Enum.reverse
    path          = path |> Enum.reverse
    obj = get_in(map, path)
    put_in(map, path, Map.delete(obj, item))
  end

  @doc "Turns all string map keys into atoms, leaving existing atoms alone (only top level)"
  def atomify(map) do
    map
    |> Enum.map(fn({k,v})-> {Prelude.String.to_atom(k), v} end)
    |> Enum.into(%{})
  end

  @doc "Turns all atom map keys into strings, leaving existing strings alone (only top level)"
  def stringify(map) do
    map
    |> Enum.map(fn({k,v})-> {Prelude.Atom.to_string(k), v} end)
    |> Enum.into(%{})
  end

  @doc "Converts strings to atoms, but leaves existing atoms alone"
  def to_atom(x) when is_atom(x),   do: x
  def to_atom(x) when is_binary(x), do: String.to_atom(x)

  @doc "Appends to an array value in a map, creating one if the key does not exist"
  def append_list(map, key, val) do
    Map.update(map, key, [val], fn(x)-> List.insert_at(x, 0, val) end)
  end

  @doc "Switch the keys with the values in a map"
  def switch(map) when is_map(map) do
    map
    |> Enum.map(fn({k, v})-> {v, k} end)
    |> Enum.into(%{})
  end
end

