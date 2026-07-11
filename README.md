# LazyCat Microserver hclient-cli - Nix Flake

[![Nix Flake Check](https://img.shields.io/badge/flake-check-passing-brightgreen)](./flake.nix)
[![License](https://img.shields.io/badge/license-unfree-red)](./default.nix)
[![Platform](https://img.shields.io/badge/platform-x86__64--linux-blue)](./default.nix)

`hclient-cli` 的 Nix flake 封装，面向 LazyCat Microserver 的命令行登录、盒子管理、TUI、daemon、代理和 TUN 网络场景。

此 flake 按照 [lazycat-cloud-client-flake](https://github.com/zerokaze420/lazycat-cloud-client-flake) 的权限模型实现：包内保留真实二进制，NixOS 模块通过 `security.wrappers` 给真实二进制授予 `CAP_NET_ADMIN`，入口脚本优先调用 `/run/wrappers/bin/hclient-cli`。

---

## 快速开始

```bash
# 查看帮助
NIXPKGS_ALLOW_UNFREE=1 nix run github:zerokaze420/lazycat-cloud-server-flake --impure -- --help

# 进入临时 shell
NIXPKGS_ALLOW_UNFREE=1 nix shell github:zerokaze420/lazycat-cloud-server-flake --impure

# 安装到 profile
NIXPKGS_ALLOW_UNFREE=1 nix profile install github:zerokaze420/lazycat-cloud-server-flake --impure
```

> 注意：此包使用 `unfree` 许可证，直接通过 flake 运行时需要 `NIXPKGS_ALLOW_UNFREE=1` 和 `--impure`。

---

## 安装方式对比

| 特性 | NixOS 模块 | Home Manager 模块 | 直接 `nix run/shell/profile` |
|------|-----------|------------------|-----------------------------|
| 安装范围 | 系统级 | 用户级 | 当前命令或用户 profile |
| CLI 基础命令 | 支持 | 支持 | 支持 |
| TUN / daemon 网络能力 | 完整支持 | 不处理权限 | 不处理权限 |
| `CAP_NET_ADMIN` | 自动配置 | 不支持 | 不支持 |
| AppArmor 支持 | 可选宽松策略 | 不涉及 | 不涉及 |

推荐在 NixOS 上使用 NixOS 模块安装，这样 `daemon`、`check`、代理和 TUN 相关功能可以获得所需的 `CAP_NET_ADMIN` 权限。Home Manager 模块只负责把 CLI 放入用户环境，无法授予 Linux capability。

> 不能和 `lazycat-cloud-client` 同时启用。两者都会管理 LazyCat 本地客户端/daemon，并会争用本地控制端口、配置目录和 TUN 运行状态。需要使用 `hclient-cli` 时，请关闭 `services.lazycat-cloud-client` 和 `programs.lazycat-cloud-client`。

---

## NixOS 模块

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    lazycat-cloud-server.url = "github:zerokaze420/lazycat-cloud-server-flake";
  };

  outputs = { self, nixpkgs, lazycat-cloud-server, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      modules = [
        lazycat-cloud-server.nixosModules.default
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            lazycat-cloud-server.overlays.default
          ];

          services.hclient-cli = {
            enable = true;
            user = "your-user";
            group = "users";
            configDir = "/home/your-user/.config/hportal-client";
            enableAppArmor = true;
            # package = pkgs.hclient-cli;
          };
        })
      ];
    };
  };
}
```

### 选项

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `services.hclient-cli.enable` | `bool` | `false` | 启用系统级安装 |
| `services.hclient-cli.package` | `package` | `pkgs.hclient-cli` | 覆写使用的包 |
| `services.hclient-cli.user` | `nullOr str` | `null` | daemon 运行用户，设为桌面用户可复用该用户的登录状态 |
| `services.hclient-cli.group` | `nullOr str` | `null` | daemon 运行用户组 |
| `services.hclient-cli.configDir` | `nullOr str` | `null` | 通过 `HCLIENT_CLI_CFG` 指定 daemon 使用的配置目录 |
| `services.hclient-cli.daemon.enable` | `bool` | `true` | 启用声明式 systemd daemon |
| `services.hclient-cli.daemon.tunMode` | `enum` | `"enabled"` | daemon 的 TUN 模式 |
| `services.hclient-cli.daemon.proxyMode` | `enum` | `"enabled"` | daemon 的代理模式 |
| `services.hclient-cli.daemon.proxyListenAddr` | `str` | `"127.0.0.1:61090"` | daemon 代理监听地址 |
| `services.hclient-cli.enableAppArmor` | `bool` | `false` | 添加宽松 AppArmor 策略 |

模块会自动：

- 安装 `hclient-cli`
- 通过 `security.wrappers.hclient-cli` 授予 `cap_net_admin+ep`
- 创建 `hclient-cli.service`，运行 `hclient-cli daemon`
- 让 `${pkgs.hclient-cli}/bin/hclient-cli` 优先进入 `/run/wrappers/bin/hclient-cli`
- 拦截上游 `install` / `upgrade` / `uninstall`，避免写入 `/usr/local/bin` 和 `/etc/systemd/system`
- 可选添加 unconfined AppArmor profile

> 上游 `hclient-cli install` 是非 Nix 的托管安装流程，会尝试复制二进制、执行 `setcap`、写 systemd service。这个 flake 已由 NixOS 模块声明式管理 service 和 capability，因此不要再运行上游 install/upgrade/uninstall。
>
> 模块会拒绝和 `services.lazycat-cloud-client.enable = true` 同时启用；如果你之前安装了 LazyCat Cloud Client，也要关闭 Home Manager 里的 `programs.lazycat-cloud-client`，避免用户级客户端继续拉起同一套本地 daemon。

---

## Home Manager 模块

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    lazycat-cloud-server.url = "github:zerokaze420/lazycat-cloud-server-flake";
  };

  outputs = { self, nixpkgs, home-manager, lazycat-cloud-server, ... }: {
    homeConfigurations.your-user = home-manager.lib.homeManagerConfiguration {
      modules = [
        lazycat-cloud-server.homeManagerModules.default
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            lazycat-cloud-server.overlays.default
          ];

          programs.hclient-cli = {
            enable = true;
            # package = pkgs.hclient-cli;
          };
        })
      ];
    };
  };
}
```

### 选项

| 选项 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `programs.hclient-cli.enable` | `bool` | `false` | 启用用户级安装 |
| `programs.hclient-cli.package` | `package` | `pkgs.hclient-cli` | 覆写使用的包 |

> Home Manager 模块不会处理 `CAP_NET_ADMIN`。需要完整网络能力时，请配合 NixOS 模块使用。

---

## Overlay

```nix
{
  nixpkgs.overlays = [
    lazycat-cloud-server.overlays.default
  ];
}
```

启用后可使用：

- `pkgs.hclient-cli`
- `pkgs.lazycat-cloud-server`

---

## 常用命令

```bash
hclient-cli --help
hclient-cli tui
hclient-cli check
hclient-cli daemon --tun enabled --proxy enabled
hclient-cli login qr
hclient-cli box list
```

`hclient-cli install`、`hclient-cli upgrade` 和 `hclient-cli uninstall` 是上游 CLI 自带的托管安装/升级流程，会被本 flake 的 wrapper 拦截。在 Nix 环境中请通过 NixOS module 管理 daemon，通过 flake 更新版本。

---

## 非自由软件

此包使用 `unfree` 许可证。NixOS 配置中可按包名允许：

```nix
{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "hclient-cli"
    ];
}
```

临时运行可使用：

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run github:zerokaze420/lazycat-cloud-server-flake --impure -- --version
```

---

## 架构

| 架构 | 状态 |
|------|------|
| `x86_64-linux` | 支持 |
| `aarch64-linux` | 暂不支持，上游当前链接只提供 amd64 二进制 |

---

## 开发

```bash
NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure
NIXPKGS_ALLOW_UNFREE=1 nix build --impure
./result/bin/hclient-cli --help
```

项目结构：

```text
.
├── flake.nix
├── flake.lock
├── default.nix
├── nixos-module.nix
├── hm-module.nix
└── .github/workflows/ci.yml
```
