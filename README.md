# LazyCat Microserver hclient-cli - Nix Flake

Nix flake for `hclient-cli`.

## Quick Start

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run . --impure -- --help
```

## NixOS Module

```nix
{
  inputs.hclient-cli.url = "path:/home/tux/code/lazycat-cloud-server-flake";

  outputs = { self, nixpkgs, hclient-cli, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      modules = [
        hclient-cli.nixosModules.default
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            hclient-cli.overlays.default
          ];

          services.hclient-cli = {
            enable = true;
            enableAppArmor = true;
          };
        })
      ];
    };
  };
}
```

The NixOS module installs the package and grants `CAP_NET_ADMIN` to the
managed binary through `security.wrappers`, matching the permission model used
by the LazyCat Cloud desktop client flake.

## Home Manager Module

```nix
{
  programs.hclient-cli.enable = true;
}
```

Home Manager only installs the package. It cannot grant Linux capabilities;
use the NixOS module for full TUN/network support.

## Overlay

```nix
{
  nixpkgs.overlays = [
    hclient-cli.overlays.default
  ];
}
```

After enabling the overlay, use `pkgs.hclient-cli` or
`pkgs.lazycat-cloud-server`.
