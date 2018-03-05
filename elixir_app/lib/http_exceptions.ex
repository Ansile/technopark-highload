defmodule HTTP400 do
  defexception message: "HTTP 400 Bad Request"
end

defmodule HTTP403 do
  defexception message: "HTTP 404 Forbidden"
end

defmodule HTTP404 do
  defexception message: "HTTP 404 Not Found"
end

defmodule HTTP405 do
  defexception message: "HTTP 405 Method Not Allowed"
end