(* Out-of-the-box supported CI list.
 * Fisrt element of a pair is the environement variable to test
 * Second element is the pair composed of the "service_name"
 * and of the environement variable containing "service_job_id" *)
let otb_support =
  ["TRAVIS", ("travis-ci", "TRAVIS_JOB_ID");
   "CIRCLECI", ("circleci", "CIRCLE_BUILD_NUM");
   "SEMAPHORE", ("semaphore", "REVISION");
   "JENKINS_URL", ("jenkins", "BUILD_ID");
   "CI_NAME", ("codeship", "CI_BUILD_NUMBER")]

let usage = "usage: bisectToCoveralls files"

(* Call the bisect command to generate a json file from inputs files
 * ( you probably want to use *.out) *)
let generate_json json_file job_id service_name inputs =
  Sys.command @@
    "bisect-report "
    ^ " -coveralls-property service_job_id " ^ job_id
    ^ " -coveralls-property service_name " ^ service_name
    ^ " -coveralls " ^ json_file
    ^ " " ^ inputs
                               
(* Send the json file using curl *)
let send_json json_file =
  Sys.command @@  "curl -F json_file=@" ^ json_file ^ " https://coveralls.io/api/v1/jobs"

(* main *)
let _ =
  let (service_name, job_id) =
    let test_env s = try ignore (Sys.getenv s); true with Not_found -> false in
    let service_infos =
      snd @@ List.find (fun (x, _) -> test_env x) otb_support in
    (fst service_infos, Sys.getenv @@ snd service_infos) in
  let json_file = service_name ^ "-" ^ job_id ^ ".json"
  and inputs = String.concat " " @@ Array.to_list Sys.argv in
  ignore(generate_json json_file job_id service_name inputs);
  ignore(send_json json_file)
