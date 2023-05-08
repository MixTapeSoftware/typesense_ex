defmodule Typesense.ClientTest do
  use ExUnit.Case
  alias TypeSense.Client
  doctest Client

  test "validate/1 missing nodes" do
    err_msg = """
    Missing required configuration. Ensure that nodes[][:protocol], nodes[][:host] and nodes[][:port] are set.
    """

    assert {:error, err_msg} == Client.new(%{})
  end

  test "validate/1 not a list of nodes" do
    err_msg = """
    The nodes configuration should contain a list of nodes.
    """

    assert {:error, err_msg} ==
             Client.new(%{
               nodes: %{
                 host: "localhost",
                 port: "8108",
                 protocol: "http"
               }
             })
  end

  test "validate/1 node missing data" do
    err_msg = "One or more node configurations is missing data."

    assert {:error, err_msg} ==
             Client.new(%{
               nodes: [
                 %{
                   host: "localhost",
                   protocol: "http"
                 },
                 %{
                   host: "localhost",
                   port: "7108",
                   protocol: "http"
                 }
               ]
             })
  end
end
