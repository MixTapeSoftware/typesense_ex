defmodule TypesenseExCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      setup :verify_on_exit!

      use Mimic

      @valid_nodes [
        %{host: "localhost", port: "8107", protocol: "https"},
        %{host: "localhost", port: "8108", protocol: "https"}
      ]

      @minimal_valid_config %{
        api_key: "123",
        connection_timeout: 0,
        num_retries: 2,
        nodes: @valid_nodes,
        # A convenience to prevent tests from being slow
        healthcheck_interval: 0
      }

      def assert_misconfig(module, config, msg) do
        Process.flag(:trap_exit, true)
        assert {:error, msg} == apply(module, :start_link, [config])
        assert_receive {:EXIT, _pid, ^msg}
      end
    end
  end
end
