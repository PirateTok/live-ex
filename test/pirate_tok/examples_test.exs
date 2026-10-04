defmodule PirateTok.ExamplesTest do
  # F17: every example parses, and every PirateTok.Live.* call in it resolves to an
  # exported function with that arity (catches API drift without hitting TikTok).
  use ExUnit.Case, async: true

  @examples Path.wildcard(Path.join([__DIR__, "..", "..", "examples", "*.exs"]))

  test "examples exist" do
    names = Enum.map(@examples, &Path.basename/1)

    for required <- ~w(online_check.exs basic_chat.exs stream_info.exs gift_streak.exs profile_lookup.exs audience.exs) do
      assert required in names, "missing example #{required}"
    end
  end

  for path <- @examples do
    @path path
    test "example #{Path.basename(path)} parses and its PirateTok calls resolve" do
      ast = @path |> File.read!() |> Code.string_to_quoted!(file: @path)

      # `alias PirateTok.Live.X` → X resolves to the full module
      {_, aliases} =
        Macro.prewalk(ast, %{}, fn
          {:alias, _, [{:__aliases__, _, [:PirateTok | _] = parts} | _]} = node, acc ->
            {node, Map.put(acc, List.last(parts), parts)}

          node, acc ->
            {node, acc}
        end)

      {_, calls} =
        Macro.prewalk(ast, [], fn
          {{:., _, [{:__aliases__, _, [head | rest]}, fun]}, _, args} = node, acc when is_list(args) ->
            parts = if head == :PirateTok, do: [head | rest], else: Map.get(aliases, head)
            if parts, do: {node, [{Module.concat(parts ++ if(head == :PirateTok, do: [], else: rest)), fun, length(args)} | acc]}, else: {node, acc}

          node, acc ->
            {node, acc}
        end)

      assert calls != [], "example makes no PirateTok calls"

      for {mod, fun, arity} <- calls do
        Code.ensure_loaded!(mod)
        assert function_exported?(mod, fun, arity), "#{inspect(mod)}.#{fun}/#{arity} does not exist"
      end
    end
  end
end
