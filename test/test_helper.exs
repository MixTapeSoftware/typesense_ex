Mox.defmock(Typesense.MockHttp, for: Typesense.Http)
Application.put_env(:typesense, :http_library, Typesense.MockHttp)

ExUnit.start()
