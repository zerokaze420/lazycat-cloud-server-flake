# LazyCat Microserver hclient-cli - Nix Flake

[![Nix Flake Check](https://img.shields.io/badge/flake-check-passing-brightgreen)](./flake.nix)
[![License](https://img.shields.io/badge/license-unfree-red)](./default.nix)
[![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20riscv64-blue)](./default.nix)

`hclient-cli` 的 Nix flake 封装，面向 LazyCat Microserver 的命令行登录、盒子管理、TUI、daemon、代理和 TUN 网络场景。

此 flake 按照 [lazycat-cloud-client-flake](https://github.com/zerokaze420/lazycat-cloud-client-flake) 的权限模型实现：包内保留真实二进制，NixOS 模块通过 `security.wrappers` 给真实二进制授予 `CAP_NET_ADMIN`，入口脚本优先调用 `/run/wrappers/bin/hclient-cli`。

---

## 快速开始

```bash
# 查看帮助
nix run github:zerokaze420/lazycat-cloud-server-flake -- --help

# 进入临时 shell
nix shell github:zerokaze420/lazycat-cloud-server-flake

# 安装到 profile
nix profile install github:zerokaze420/lazycat-cloud-server-flake
```

> 注意：此包使用 `unfree` 许可证。本 flake 在自己的 nixpkgs 实例上启用了 `config.allowUnfree`，因此上面这些命令不再需要 `--impure` 和 `NIXPKGS_ALLOW_UNFREE=1`。如果你是通过 overlay 在自己的 nixpkgs 里使用该包，则仍需自行允许 unfree。

---

## 安装方式对比

| 特性 | NixOS 模块 | Home Manager 模块 | 直接 `nix run/shell/profile` |
|------|-----------|------------------|-----------------------------|
| 安装范围 | 系统级 | 用户级 | 当前命令或用户 profile |
| 支持系统 | 仅 Linux | Linux + macOS | Linux + macOS |
| CLI 基础命令 | 支持 | 支持 | 支持 |
| TUN / daemon 网络能力 | 完整支持 | 不处理权限 | 不处理权限 |
| `CAP_NET_ADMIN` | 自动配置 | 不支持 | 不支持 |
| AppArmor 支持 | 可选宽松策略 | 不涉及 | 不涉及 |

推荐在 NixOS 上使用 NixOS 模块安装，这样 `daemon`、`check`、代理和 TUN 相关功能可以获得所需的 `CAP_NET_ADMIN` 权限。Home Manager 模块只负责把 CLI 放入用户环境，无法授予 Linux capability。

> NixOS 模块依赖 systemd 和 `security.wrappers`，只能在 Linux 上使用；在 Darwin 上启用会直接断言失败，请改用 Home Manager 模块。
>
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

此包使用 `unfree` 许可证。通过 flake 的 `packages` 使用时已由 flake 自动允许；如果你通过 overlay 把它放进自己的 nixpkgs，则需要自行允许，例如按包名：

```nix
{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "hclient-cli"
    ];
}
```

临时运行可直接使用：

```bash
nix run github:zerokaze420/lazycat-cloud-server-flake -- --version
```

---

## 架构

`default.nix` 按当前系统自动选择上游发布的对应二进制，`flake.nix` 声明的系统列表与之一一对应：

| 系统 | 上游二进制 | 状态 |
|------|-----------|------|
| `x86_64-linux` | `hclient-cli-linux-amd64` | 支持 |
| `aarch64-linux` | `hclient-cli-linux-arm64` | 支持 |
| `riscv64-linux` | `hclient-cli-linux-riscv64` | 支持（原生需 riscv64 机器，否则用交叉输出） |
| `x86_64-darwin` | `hclient-cli-darwin-amd64` | 支持 |
| `aarch64-darwin` | `hclient-cli-darwin-arm64` | 支持 |

其他系统（如 `loongarch64-linux`、`armv7l-linux`、`i686-linux`、`powerpc64le-linux`）上游没有对应二进制，不在支持范围内。

### riscv64

上游确实提供 riscv64 静态二进制（`ELF 64-bit LSB executable, UCB RISC-V, double-float ABI`），但它在 Nix 里比较特殊：

- **原生构建需要 riscv64 机器。** nixpkgs 把 `bootstrap-tools` 作为预编译的 fixed-output derivation 发布，所以 x86_64 机器无法从零构建出 riscv64 的 stdenv，会直接报 `platform mismatch`。在真正的 riscv64 主机上 `packages.riscv64-linux` 可以正常构建，但 GitHub 没有 riscv64 runner。
- **交叉编译可用，且已验证。** 从 `x86_64-linux` / `aarch64-linux` 用 `pkgsCross.riscv64` 构建时，bootstrap 保持原生，只有 `hostPlatform` 变成 riscv64，因此可以正常构建：

```bash
nix build .#packages.x86_64-linux.hclient-cli-riscv64
# 或别名
nix build .#riscv64Packages.x86_64-linux

# 在非 riscv64 机器上执行（用户态模拟）
qemu=$(nix build --no-link --print-out-paths --impure --expr \
  'let f = builtins.getFlake (toString ./.); p = import f.inputs.nixpkgs { system = "x86_64-linux"; }; in p.qemu-user')
"$qemu/bin/qemu-riscv64" ./result/lib/hclient-cli/.hclient-cli-wrapped --help
```

上面的 qemu 执行路径已在本仓库实测通过。

> `x86_64-darwin` 比较特殊：nixpkgs 26.11（当前 nixos-unstable）已经彻底移除该平台，`import nixpkgs { system = "x86_64-darwin"; }` 会直接报错。因此 flake 用单独的 `nixpkgs-darwin` input（`nixpkgs-26.05-darwin`，即 nixpkgs 自己推荐的 Intel macOS 分支）来构建这个包。如果你在 Intel macOS 上通过 overlay 使用，`final` 来自你自己的 nixpkgs，那就没法求值，请改用 flake 的 `packages` 输出。该分支的安全更新支持到 2026 年底。
>
> macOS 上无法提供 TUN / daemon 能力：capability、`systemd` 和 `/run/wrappers` 都是 Linux 专有机制。Darwin 用户只能通过包或 Home Manager 模块获得 CLI 本身。
>
> riscv64 的 NixOS 模块路径与其他 Linux 相同（systemd + `security.wrappers`），但需要内核支持 `tun`。

---

## 开发

```bash
# 评估所有声明的系统（不构建）
nix flake check --all-systems --no-build

# 构建本机包
nix build
./result/bin/hclient-cli --help

# 查看 flake 输出
nix flake show
```

> 因为 flake 自身启用了 `config.allowUnfree`，本地 `nix flake check` / `nix build` 不再需要 `--impure` 或 `NIXPKGS_ALLOW_UNFREE=1`。

CI 在 `.github/workflows/ci.yml` 中定义，包含四个 job：

- `plan`：从 flake 读取 `.#systems` 与 `.#ci.buildTargets`，用 jq 算出原生构建矩阵。两个列表都来自 flake，新增平台会自动新增 CI job。
- `eval`：`nix flake show` + `nix flake check --all-systems --no-build`，校验所有声明系统（含 riscv64-linux）都能求值。
- `build`：在原生 runner 上为每个系统真实构建两个 package，并执行产物冒烟测试。
- `riscv64`：交叉构建 riscv64 包，断言产物确实是 RISC-V ELF，再用 `qemu-riscv64` 真实执行 `--help`。

各系统对应的 runner：`x86_64-linux` → `ubuntu-22.04`，`aarch64-linux` → `ubuntu-24.04-arm`，`x86_64-darwin` → `macos-15-intel`，`aarch64-darwin` → `macos-14`；riscv64 在 `ubuntu-22.04` 上交叉构建后模拟执行。

> qemu 采用的是**直接调用** `qemu-riscv64`，而不是注册 `binfmt_misc`。后者需要在 hosted runner 上做特权配置，更容易碎。

构建缓存使用 `DeterminateSystems/magic-nix-cache-action`（PR）和可选的 Cachix（配置 `CACHIX_AUTH_TOKEN` secret 后自动启用，未配置时跳过）。

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
