Application.put_env(:typesense_ex, :client_config, %{
  api_key: "MY_TYPESENSE_API_KEY",
  nodes: [
    %{host: "localhost", port: "8109", protocol: "http"},
    %{host: "localhost", port: "8108", protocol: "http"}
  ]
})

ExUnit.start()
