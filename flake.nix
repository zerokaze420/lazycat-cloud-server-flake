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

    # Platforms upstream publishes a binary for, as flake systems. riscv64-linux
    # is listed because nixpkgs exposes it, but building it natively needs a
    # riscv64 builder: nixpkgs ships `bootstrap-tools` as a prebuilt fixed-output
    # derivation, so an x86_64 machine cannot produce a riscv64 stdenv. From a
    # x86_64 or aarch64 host, use the cross outputs below instead.
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "riscv64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    # Hosts that can cross-compile to riscv64 while keeping a native bootstrap.
    riscvCrossHosts = [ "x86_64-linux" "aarch64-linux" ];

    # Systems buildable on GitHub-hosted runners, mapped to their runner.
    # riscv64-linux is deliberately absent: it is cross-built and emulated in a
    # dedicated CI job rather than built natively.
    ciBuildTargets = {
      "x86_64-linux" = "ubuntu-22.04";
      "aarch64-linux" = "ubuntu-24.04-arm";
      "x86_64-darwin" = "macos-15-intel";
      "aarch64-darwin" = "macos-14";
    };

    # Intel macOS needs a nixpkgs that still supports it.
    nixpkgsFor = system:
      if system == "x86_64-darwin" then nixpkgs-darwin else nixpkgs;

    forAllSystems = lib.genAttrs systems;

    mkPkgs = system: import (nixpkgsFor system) {
      inherit system;
      config.allowUnfree = true;
    };
  in
  {
    packages = forAllSystems (system: let
      pkgs = mkPkgs system;
      native = {
        default = pkgs.callPackage ./default.nix { };
        hclient-cli = pkgs.callPackage ./default.nix { };
      };
      # Cross-compiled riscv64 build, available only from hosts that can
      # produce it without a riscv64 builder.
      crossRiscv = lib.optionalAttrs (lib.elem system riscvCrossHosts) {
        hclient-cli-riscv64 = pkgs.pkgsCross.riscv64.callPackage ./default.nix { };
      };
    in native // crossRiscv);

    # Convenience aliases for the riscv64 build, one entry point per able host.
    riscv64Packages =
      lib.genAttrs riscvCrossHosts (system: self.packages.${system}.hclient-cli-riscv64);

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

    # Consumed by CI so its matrices stay in sync with what is declared here
    # instead of hardcoding lists of their own.
    inherit systems;
    ci = {
      buildTargets = ciBuildTargets;
      riscvCrossBuilders = riscvCrossHosts;
    };
  };
}
