defmodule TypesenseExCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      setup :verify_on_exit!
      use Mimic
    end
  end
end
