{ writeShellApplication, deno }:

writeShellApplication {
  name = "linear";
  runtimeInputs = [ deno ];
  text = ''
    exec ${deno}/bin/deno run -A --reload -q jsr:@schpet/linear-cli "$@"
  '';
}
