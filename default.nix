{ lib
, stdenv
, fetchurl
}:

let
  version = "1.1.3";

  # Upstream publishes one prebuilt binary per OS/architecture. The CDN has no
  # soft-404 behaviour: an unpublished artefact returns a real 404, so every
  # entry below is verified to exist.
  sources = [
    {
      system = "x86_64-linux";
      file = "hclient-cli-linux-amd64";
      hash = "sha256-d7/cSfOr//0bHBy46hliqAaAo9zfnDYKjxA9ZAw02E4=";
    }
    {
      system = "aarch64-linux";
      file = "hclient-cli-linux-arm64";
      hash = "sha256-sLuymeG3mbx0gRViI04K6T2XuP8S9QkbHcX7xmxNiWM=";
    }
    {
      system = "x86_64-darwin";
      file = "hclient-cli-darwin-amd64";
      hash = "sha256-WEuYTLjdeCcBImtPqq1YwiET2pVwfjdPO8R8+hdZyNE=";
    }
    {
      system = "aarch64-darwin";
      file = "hclient-cli-darwin-arm64";
      hash = "sha256-cTfwp4nE99Zta2D4M79q+pobGD8bY2LNwh5lrpZh/Qs=";
    }
  ];

  # Resolved after the platform is known, so evaluation stays derivational and
  # no branch needs to throw.
  source = lib.findFirst (s: s.system == stdenv.hostPlatform.system) null sources;
in

stdenv.mkDerivation (finalAttrs: {
  pname = "hclient-cli";
  inherit version;

  src = fetchurl {
    url = "https://dl.lazycatmicroserver.com/hclient-cli/v${version}/${source.file}";
    inherit (source) hash;
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/lib/hclient-cli

    install -Dm755 $src $out/lib/hclient-cli/.hclient-cli-wrapped

    cat > $out/bin/hclient-cli << 'WRAPPEREOF'
#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    install|upgrade|uninstall)
      cat >&2 <<'MSG'
hclient-cli is managed by Nix.

The upstream managed install commands write to /usr/local/bin and
/etc/systemd/system, which is not compatible with this flake.

On NixOS, enable services.hclient-cli and let the module manage the daemon.
For upgrades, update the flake input or package version instead.
MSG
      exit 1
      ;;
  esac
done

if [ -x /run/wrappers/bin/hclient-cli ]; then
  exec /run/wrappers/bin/hclient-cli "$@"
fi
exec @out@/lib/hclient-cli/.hclient-cli-wrapped "$@"
WRAPPEREOF
    substituteInPlace $out/bin/hclient-cli --replace-fail "@out@" "$out"
    chmod +x $out/bin/hclient-cli

    runHook postInstall
  '';

  meta = with lib; {
    description = "LazyCat Microserver hclient command line client";
    homepage = "https://lazycat.cloud";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "hclient-cli";
    platforms = map (s: s.system) sources;
    maintainers = with maintainers; [ ];
  };
})
