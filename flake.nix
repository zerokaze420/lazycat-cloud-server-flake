{
  description = "LazyCat Microserver hclient-cli Nix flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nixpkgs 26.11 (current nixos-unstable) dropped x86_64-darwin entirely, so
    # the Intel macOS package is built from the branch nixpkgs itself points
    # users at. Nothing else consumes this input.
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
  };

  outputs = { self, nixpkgs, nixpkgs-darwin }: let
    lib = nixpkgs.lib;

    # Platforms upstream actually publishes a binary for. default.nix selects
    # the matching artefact from this same set.
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    forAllSystems = lib.genAttrs systems;

    # Route each system to a nixpkgs that still supports it.
    nixpkgsFor = system:
      if system == "x86_64-darwin" then nixpkgs-darwin else nixpkgs;

    # The package is unfree, so allow it on the flake's own nixpkgs instance.
    # Consumers using the overlay keep their own nixpkgs config.
    mkPkgs = system:
      if lib.elem system systems then
        import (nixpkgsFor system) {
          inherit system;
          config.allowUnfree = true;
        }
      else
        throw ''
          lazycat-cloud-server-flake: unsupported system "${system}".

          Upstream only publishes binaries for:
            ${lib.concatStringsSep ", " systems}

          Other systems (for example riscv64-linux) have no upstream artefact.
        '';
  in
  {
    packages = forAllSystems (system: let
      pkgs = mkPkgs system;
    in {
      default = pkgs.callPackage ./default.nix { };
      hclient-cli = pkgs.callPackage ./default.nix { };
    });

    # The overlay is applied to whatever nixpkgs the consumer already uses. On
    # x86_64-darwin with nixos-unstable that nixpkgs cannot evaluate at all, so
    # use the flake's packages output there instead.
    overlays.default = final: prev: {
      hclient-cli = final.callPackage ./default.nix { };
      lazycat-cloud-server = final.callPackage ./default.nix { };
    };

    # The NixOS module manages a systemd unit plus a cap_net_admin wrapper, so
    # it is Linux-only by construction.
    nixosModules = {
      hclient-cli = import ./nixos-module.nix;
      default = self.nixosModules.hclient-cli;
    };

    # Home Manager only adds the CLI to the user profile, which works on Darwin
    # too, but without any network capability.
    homeManagerModules = {
      hclient-cli = import ./hm-module.nix;
      default = self.homeManagerModules.hclient-cli;
    };

    # Consumed by CI so the workflow matrix stays in sync with the systems
    # declared here instead of hardcoding its own list.
    inherit systems;
  };
}
