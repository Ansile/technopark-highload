defmodule Server do
  @listener 80
  @path "/Users/ansile/http-test-suite"

  @stream_buffer_size 16384

  def start do
    IO.puts @listener
    server = Socket.TCP.listen!(@listener, options: [:nodelay])

    processClient(server)
  end

  def processClient(server) do
    timestamp = :os.system_time(:milli_seconds)
    client = server |> Socket.accept!()
    timestamp2 = :os.system_time(:milli_seconds)

    if (timestamp2 - timestamp) >= 100 do
      IO.puts "Too slow in acception"
      IO.puts timestamp2 - timestamp
    end

    main = Task.async(Server, :processRequest, [client, true])
#    processRequest(client, true)
    Task.await(main, 100)

#    spawn(Server, :processRequest, [client, true])

    processClient(server)
  end

  def processRequest(client, stub \\ false) do
    send_through_socket = fn (arg) -> Socket.Stream.send!(client, arg) end
    timestamp = :os.system_time(:milli_seconds)
    request_payload = client |> Socket.Stream.recv!([timeout: 99])
    timestamp2 = :os.system_time(:milli_seconds)
    if (timestamp2 - timestamp) >= 100 do
      IO.puts "Too slow in stream"
      IO.puts timestamp2 - timestamp
    end

    if (!stub) do
      try do
        request = Request.fromString!(request_payload)


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
  #
        file = File.stream!(path, [], @stream_buffer_size)

        fileLength = case File.stat(path) do
          {:ok, %{size: fileLength}} -> fileLength
          {:error, reason} -> raise chooseException(path, reason)
        end

        IO.puts fileLength

        Response.responseString(200, "", fileLength, MIME.Types.path(request[:path])) |> send_through_socket.()

        if(request[:method] == :GET) do
  #        Socket.Stream.io!(client, file)
          :ok = Enum.each(file, &Socket.Stream.send(client, &1))
        end
      rescue
        HTTP400 -> client |> Socket.Stream.send(Response.responseString(400))
        HTTP403 -> client |> Socket.Stream.send(Response.responseString(403))
        HTTP404 -> client |> Socket.Stream.send(Response.responseString(404))
        HTTP405 -> client |> Socket.Stream.send(Response.responseString(405))
      after
        client |> Socket.Stream.close()
      end
      else
        Response.stub() |> send_through_socket.()
        client |> Socket.Stream.close()
      end

      timestamp3 = :os.system_time(:milli_seconds)
      if (timestamp3 - timestamp2) >= 100 do
        IO.puts "Too slow elsewhere"
        IO.puts timestamp3 - timestamp2
      end
  end

  def chooseException(path, reason \\ "") do
    IO.puts path
    IO.puts reason
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
    date = "Date: #{elem(Timex.format(Timex.now, "{RFC1123}"), 1)}\r\n"
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

  def stub() do
    metaData = "HTTP/1.1 200\r\n"
    server = "Server: highload-corutines\r\n"
    connection = "Connection: Close\r\n"

    Enum.join([metaData, server, connection])
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