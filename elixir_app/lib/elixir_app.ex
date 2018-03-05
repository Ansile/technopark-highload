defmodule Server do
  @default_listener_port 80
  @default_file_path "../content"
  @config_path "../httpd.conf"

  @stream_buffer_size 64 * 1024

  @debug false

  def start do
    config = ConfigReader.parseToMap(@config_path)

    port = case Integer.parse(config["listen"]) do
      { number, _ } -> number
      :error -> @default_listener_port
    end

    server = Socket.TCP.listen!(port, options: [:nodelay])
    IO.puts inspect server
#    {:ok, lsock} = :gen_tcp.listen(5678, [:binary, {:packet, 0}, {:active, false}])

#    IO.puts inspect lsock
    processClient(server, config["document_root"] || @default_file_path)
  end

  def processClient(server, fileFolder) do
    timestamp = :os.system_time(:milli_seconds)
#    client = server |> Socket.accept!()

    {:ok, client_erl} = server |> :gen_tcp.accept()
#    IO.puts inspect client_erl

    timestamp2 = :os.system_time(:milli_seconds)

    if (timestamp2 - timestamp) >= 100 do
      IO.puts "Too slow in acception"
      IO.puts timestamp2 - timestamp
    end

    spawn(Server, :processRequest, [client_erl, fileFolder])

    processClient(server, fileFolder)
  end

  def processMockErlang(client) do
#    :gen_tcp.recv(client, 0)
#    IO.puts inspect client
    do_recv(client, [])
#    :gen_tcp.
    :ok = :gen_tcp.close(client)
  end

  def do_recv(sock, bs) do
    case :gen_tcp.recv(sock, 0) do
         {:ok, nil} -> do_recv(sock, bs)
         {:ok, ""} -> do_recv(sock, bs)
         {:ok, b} -> {:ok, b}
         {:error, closed} -> IO.puts inspect{:closed, :erlang.list_to_binary(bs)}
    end
  end

  def processMockElixir(client) do
    request_payload = client |> Socket.Stream.recv!()
    client |> Socket.Stream.close()
  end

  def processRequest(client, fileFolder) do
    send_through_socket = fn (arg) -> Socket.Stream.send!(client, arg) end
    timestamp = :os.system_time(:milli_seconds)
    request_payload = client |> Socket.Stream.recv!()
    timestamp2 = :os.system_time(:milli_seconds)
    if (timestamp2 - timestamp) >= 100 do
      IO.puts "Too slow in stream"
      IO.puts timestamp2 - timestamp
    end
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
          true -> "#{fileFolder}#{request[:path]}"
      end

      if (@debug) do
        IO.puts request[:path]

        IO.puts path

        IO.puts request[:method]
      end
#
      file = File.stream!(path, [], @stream_buffer_size)

      fileLength = case File.stat(path) do
        {:ok, %{size: fileLength}} -> fileLength
        {:error, reason} -> raise chooseException(path, reason)
      end

      if (@debug) do
        IO.puts fileLength
      end

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

    timestamp3 = :os.system_time(:milli_seconds)
    if (timestamp3 - timestamp2) >= 100 do
      IO.puts "Too slow elsewhere"
      IO.puts timestamp3 - timestamp2
    end
  end

  def chooseException(path, reason \\ "") do
    if (@debug) do
      IO.puts path
      IO.puts reason
    end
    case path |> String.ends_with?("index.html") do
      false -> HTTP404
      true -> HTTP403
    end
  end

  def outputCPULimit() do
    IO.puts ConfigReader.parseToMap(@config_path)["cpu_limit"]
  end
end


defmodule Request do
  @debug false

  def fromString!(string) do
    IO.puts string
    try do
      lines = String.split(string, "\n")
      [method, pathString, protocol | _] = String.split(hd(lines))

      [path|_] = String.split(pathString, "?")

      if(@debug) do
        IO.puts(method)
      end

      filePath = URI.decode(path)

      if(@debug) do
        Enum.each(lines, &IO.puts/1)
      end

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
