{ lib
, stdenv
, fetchurl
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "hclient-cli";
  version = "1.1.3";

  src = fetchurl {
    url = "https://dl.lazycatmicroserver.com/hclient-cli/v${finalAttrs.version}/hclient-cli-linux-amd64";
    hash = "sha256-d7/cSfOr//0bHBy46hliqAaAo9zfnDYKjxA9ZAw02E4=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/lib/hclient-cli

    install -Dm755 $src $out/lib/hclient-cli/.hclient-cli-wrapped

    cat > $out/bin/hclient-cli << 'WRAPPEREOF'
#!/bin/sh
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
    platforms = [ "x86_64-linux" ];
    badPlatforms = [ "aarch64-linux" ];
    maintainers = with maintainers; [ ];
  };
})
