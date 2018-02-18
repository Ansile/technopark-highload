defmodule Server do
  @listener 80
  @path "/Users/ansile/http-test-suite"

  def start do
    IO.puts @listener
    server = Socket.TCP.listen!(@listener)

    processClient(server)
  end

  def processClient(server) do
    client = server |> Socket.accept!()

    processRequest(client)

    client |> Socket.Stream.close()

    processClient(server)
  end

  def processRequest( client) do
    request_payload = client |> Socket.Stream.recv!()

    try do
      request = Request.fromString!(request_payload)

      send_through_socket = fn (arg) -> Socket.Stream.send!(client, arg) end

      if(request[:path] |> String.contains?("../")) do
        raise HTTP404
      end
      if (request[:method] == :undefined) do
        raise HTTP405
      end

      path = cond do
        #TODO: check whether the path may not contain a leading slash
  #        String.last(@path) == "/" -> "#{@path}#{String.replace_prefix(request[:path], "/", "")}"
          true -> "#{@path}#{request[:path]}"
      end

      IO.puts request[:path]

      IO.puts path

      IO.puts request[:method]

      file = File.stream!(path, [], 16384)

      fileLength = case File.stat(path) do
        {:ok, %{size: fileLength}} -> fileLength
        {:error, _reason} -> raise chooseException(path)
      end

      IO.puts fileLength

      Response.responseString(200, "", fileLength, MIME.Types.path(request[:path])) |> send_through_socket.()

      if(request[:method] == :GET) do
        :ok = Enum.each(file, &Socket.Stream.send(client, &1))
      end
    rescue
      HTTP400 -> client |> Socket.Stream.send(Response.responseString(400))
      HTTP403 -> client |> Socket.Stream.send(Response.responseString(403))
      HTTP404 -> client |> Socket.Stream.send(Response.responseString(404))
      HTTP405 -> client |> Socket.Stream.send(Response.responseString(405))
    end
  end

  def chooseException(path) do
    case path |> String.ends_with?("index.html") do
      false -> HTTP404
      true -> HTTP403
    end
  end
end


defmodule Request do
  def fromString!(string) do
    lines = String.split(string, "\n")
    try do
      [method, pathString, protocol | _] = String.split(hd(lines))

      [path|_] = String.split(pathString, "?")

      IO.puts(method)

      filePath = URI.decode(path)


      Enum.each(lines, &IO.puts/1)

      %{:method => RequestMethod.fromString(method), :path => resolveFilePath(filePath)}
    rescue
      MatchError -> raise HTTP400
    end
  end

  def resolveFilePath(path) do
    if(path == "" || String.last(path) == "/") do
      "#{path}index.html"
    else
      path
    end
  end
end


defmodule RequestMethod do
  def fromString("HEAD"), do: :HEAD
  def fromString("GET"), do: :GET
  def fromString(_), do: :undefined
end


defmodule Response do
  def responseString(code, status \\ "", content_length \\ false, content_type \\ false) do
    metaData = "HTTP/1.1 #{code} #{status}\r\n"
    date = "Date: #{elem(Timex.format(Timex.now, "{RFC1123}"), 0)}\r\n"
    server = "Server: highload-corutines\r\n"
    connection = "Connection: Close\r\n"


    contentLen = cond do
      content_length -> "Content-Length: #{content_length}\r\n"
      true -> ""
    end

    contentType = cond do
      content_type -> "Content-Type: #{content_type}\r\n\r\n"
      true -> ""
    end

    Enum.join([metaData, date, server, connection, contentLen, contentType])
  end
end

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