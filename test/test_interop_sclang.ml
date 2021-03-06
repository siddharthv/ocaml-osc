open OUnit

type test_config = {
  ml_port: int;
  sclang_path: string;
  sc_port: int;
  sc_script_path: string;
}

let ping_sclang config packet =
  let open Osc in
  let open Osc_unix.Udp in
  let localhost = Unix.inet_addr_of_string "127.0.0.1" in
  let ml_addr = Unix.ADDR_INET (localhost, config.ml_port) in
  let sc_addr = Unix.ADDR_INET (localhost, config.sc_port) in
  (* Add the OCaml port into the packet, so SuperCollider knows where to send
   * the reply. *)
  let sent_packet =
    match packet with
    | Message {address; arguments} ->
      Message {
        address;
        arguments = (Int32 (Int32.of_int config.ml_port)) :: arguments
      }
    | Bundle _ ->
      failwith "Bundles not implemented"
  in
  bracket
    (fun () ->
      match Unix.fork () with
      | 0 ->
        (* Child -> will exec the SuperCollider echo server. *)
        Unix.execv
          config.sclang_path
          [|
            config.sclang_path;
            "-u";
            string_of_int config.sc_port;
            config.sc_script_path;
          |]
      | child_pid ->
        Printf.printf "ocaml: forked sclang with pid %d\n%!" child_pid;
        let client = Client.create () in
        let server = Server.create ml_addr 4096 in
        Printf.printf "ocaml: waiting 5 seconds for sclang to start up\n%!";
        Unix.sleep 5;
        (child_pid, client, server))
    (fun (_, client, server) ->
      Printf.printf "ocaml: sending packet to port %d\n%!" config.sc_port;
      Client.send client sc_addr sent_packet;
      Printf.printf "ocaml: packet sent\n%!";
      let (received_packet, _) = Server.recv server in
      Printf.printf "ocaml: packet received\n%!";
      Test_common.assert_packets_equal sent_packet received_packet)
    (fun (child_pid, client, server) ->
      Printf.printf "ocaml: killing sclang\n%!";
      Unix.kill child_pid Sys.sigterm;
      Client.destroy client;
      Server.destroy server)
    ()

let test_ping_sclang config =
  "test_ping_sclang" >::: (
    List.map
      (fun (name, packet) ->
        name >:: (fun () -> ping_sclang config packet))
      (* TODO: supercollider's handling of blobs via OSC is a bit suspect,
       *       so drop the test packets containing blobs for now. *)
      [
        List.nth Test_common.test_packets 0;
        List.nth Test_common.test_packets 1;
      ]
  )

let test_interop_sclang config =
  "test_interop_sclang" >:::
    [
      test_ping_sclang config;
    ]

let usage () =
  Printf.printf "Usage:\n%!";
  Printf.printf
    "%s <ml-port> <sclang-path> <sc-port> <sc-script-path>\n%!"
    Sys.executable_name

let () =
  match Sys.argv with
  | [|_; ml_port_string; sclang_path; sc_port_string; sc_script_path|] -> begin
    try
      let ml_port = int_of_string ml_port_string in
      let sc_port = int_of_string sc_port_string in
      print_endline "-------- SuperCollider interoperability tests --------";
      let config = {ml_port; sclang_path; sc_port; sc_script_path} in
      let results = run_test_tt (test_interop_sclang config) in
      (* Exit 1 if there were any errors or failures. *)
      let rec choose_exit_code results acc =
        match results with
        | [] -> acc
        | (RFailure _) :: rest
        | (RError _) :: rest -> 1
        | _ :: rest -> choose_exit_code rest acc
      in
      let exit_code = choose_exit_code results 0 in
      exit exit_code
    with (Failure "int_of_string") -> usage ()
  end
  | _ -> usage ()
