module Io = struct
  type 'a t = 'a
  let (>>=) x f = f x
  let (>|=) x f = f x
  let return x = x

  let raise_exn = raise
end

module UdpTransport = struct
  module Io = Io

  type sockaddr = Unix.sockaddr

  module Client = struct
    type t = {
      socket: Unix.file_descr;
    }

    let create () =
      let socket = Unix.socket
        Unix.PF_INET
        Unix.SOCK_DGRAM
        (Unix.getprotobyname "udp").Unix.p_proto
      in
      {socket}

    let destroy client =
      Unix.close client.socket

    let send_string client addr data =
      let length = String.length data in
      let sent = Unix.sendto client.socket data 0 length [] addr in
      if sent <> length
      then failwith "IO error"
  end

  module Server = struct
    type t = {
      buffer_length: int;
      buffer: string;
      socket: Unix.file_descr;
    }

    let create addr buffer_length =
      let buffer = String.create buffer_length in
      let socket = Unix.socket
        Unix.PF_INET
        Unix.SOCK_DGRAM
        (Unix.getprotobyname "udp").Unix.p_proto
      in
      Unix.bind socket addr;
      {buffer_length; buffer; socket}

    let destroy server =
      Unix.close server.socket

    let recv_string server =
      match Unix.recvfrom server.socket server.buffer 0 server.buffer_length []
      with
      | length, sockaddr -> String.sub server.buffer 0 length, sockaddr
  end
end

module Udp = Osc_transport.Make(UdpTransport)
