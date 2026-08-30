# Release export of the project (official Linux template, runs on glibc alone)
# and the container image that runs it as a dedicated server.
{
  lib,
  stdenv,
  autoPatchelfHook,
  godot_4_7,
  godot_4_7-export-templates-bin,
  dockerTools,
  busybox,
  writeShellScriptBin,
  src,
  version,
}:
let
  server = stdenv.mkDerivation {
    pname = "meowmau-server";
    inherit version src;

    nativeBuildInputs = [
      godot_4_7
      autoPatchelfHook
    ];

    buildPhase = ''
      runHook preBuild
      export HOME="$(mktemp -d)"
      mkdir -p "$HOME/.local/share/godot"
      ln -s ${godot_4_7-export-templates-bin}/share/godot/export_templates "$HOME/.local/share/godot/"
      # The first import of a fresh tree logs parse errors while the script
      # class cache does not exist yet; only the second pass is meaningful.
      godot --headless --import > /dev/null 2>&1 || true
      godot --headless --import 2>&1 | tee import.log
      ! grep -qE "SCRIPT ERROR|^ERROR" import.log
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/libexec/meowmau"
      godot --headless --export-release Linux "$out/libexec/meowmau/meowmau.x86_64"
      test -s "$out/libexec/meowmau/meowmau.pck"
      runHook postInstall
    '';
  };

  launcher = writeShellScriptBin "meowmau-server" ''
    exec ${server}/libexec/meowmau/meowmau.x86_64 --headless -- --server \
      --port="''${MEOWMAU_PORT:-9080}" \
      --bind="''${MEOWMAU_BIND:-0.0.0.0}" \
      --health-port="''${MEOWMAU_HEALTH_PORT:-9081}" \
      "$@"
  '';
in
{
  inherit server;

  image = dockerTools.streamLayeredImage {
    name = "meowmau-server";
    tag = "latest";
    # busybox provides /bin/sh and wget for the compose healthcheck.
    contents = [
      launcher
      busybox
    ];
    extraCommands = "mkdir -m 1777 tmp";
    config = {
      Cmd = [ "/bin/meowmau-server" ];
      # Godot's user:// (settings, logs) lives under HOME and must be writable.
      Env = [ "HOME=/tmp" ];
      ExposedPorts = {
        "9080/tcp" = { };
        "9081/tcp" = { };
      };
    };
  };
}
