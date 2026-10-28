# TCP拥塞算法BBR变体

[liquorix内核介绍](https://www.sysgeek.cn/liquorix-kernel/)

移植了以下BBR算法变体到arch的`linux-zen`或Ubuntu的`liquorix`内核:

* [nanqinlang](https://github.com/tcp-nanqinlang)
* [tsunami](https://github.com/KozakaiAya/TCP_BBR/blob/master/code/v6.1/tcp_tsunami.c)
* [bbrplus](https://github.com/cx9208/bbrplus)
* [bbr1](https://github.com/torvalds/linux/blob/master/net/ipv4/tcp_bbr.c)
* bbr3 — Google 树 BBRv3 的多版本内核 backport（见下文）

## 选择算法

需要注意的是，一些发行版内核（例如 **linux-zen**、较新的 **liquorix** 内核等）已经将内核自带的 `bbr` 实现替换为 **BBRv3**，而不再是最初的 BBRv1。

这意味着：

- 系统中看到的 `bbr` 拥塞控制算法，实际行为可能是 **BBRv3**
- 本项目中的 `bbr1` 明确对应 **原始 BBRv1** 实现，用于对比测试或兼容旧行为
- `bbrplus`、`nanqinlang`、`tsunami` 等均是基于 BBRv1/早期 BBR 思路的改进算法，与 BBRv3 的设计目标和实现细节存在明显差异
- `tcp_bbr1`模块的tcp拥塞算法名字需要改为`bbr1`
- `bbr3` 是从 Google 内核树移植的 BBRv3，通过探测式兼容层适配主线 5.4~6.6+ 内核

**使用提醒**：在实际使用中，BBRv3 在 **高 RTT / 高丢包** 的复杂网络环境（例如翻墙、跨境链路）下，吞吐和稳定性表现往往较差，不少用户反馈其带宽利用率明显低于 BBRv1 系变体。因此，**翻墙或跨境 VPS 场景不建议使用内核自带的 `bbr`（BBRv3）**，而更适合选择 `bbrplus`、`bbr1` 等算法进行测试和部署。


根据[论文](https://arxiv.org/abs/1909.03673)的评测，应该选择`bbrplus`:

```
BBRPlus is an good improvement to BBR and is highly recommended to be applied in this paper
```

你也可以根据自己需要选用其它算法。

## 编译&运行

以Ubuntu 22.04.03 LTS amd64为例：
确保你的系统有`dkms`，内核构建环境和至少有内核头文件。(Ubuntu下叫 `linux-headers-liquorix-amd64`)

```
add-apt-repository ppa:damentz/liquorix
apt update
sapt install -y git build-essential dkms \
linux-image-7.2.12-1-liquorix-amd64 linux-headers-7.2.12-1-liquorix-amd64
grep -E "menuentry |submenu " /boot/grub/grub.cfg
vim /etc/default/grub
update-grub
reboot
git clone https://github.com/hrimfaxi/tcp_bbr_modules
cd tcp_bbr_modules
```

如果在切换后遇到兼容性问题，可以在启动时通过 GRUB 菜单切回原版内核，再在终端中运行以下命令进行清理：  
```
apt purge linux-image-liquorix-amd64 linux-headers-liquorix-amd64
update-grub
```

```
make dkms
modprobe tcp_nanqinlang
modprobe tcp_tsunami
modprobe tcp_bbrplus
```
or
```
sudo dkms add .
sudo dkms build  -m tcp_bbr_modules -v 1.0
sudo dkms install -m tcp_bbr_modules -v 1.0
```

失败重来请用：  
dkms remove tcp_bbr_modules/1.0 --all


```
# 试用nanqinlang
sysctl -w net.ipv4.tcp_congestion_control=nanqinlang

# 试用tsunami
sysctl -w net.ipv4.tcp_congestion_control=tsunami

# 试用bbrplus
sysctl -w net.ipv4.tcp_congestion_control=bbrplus

# 试用bbr1
sysctl -w net.ipv4.tcp_congestion_control=bbr1

ss -tin|grep -E 'nanqinlang|tsunami|bbrplus|bbr1'
```

## 固化到系统

```
tee -a /etc/modules-load.d/tcp-cong.conf <<< tcp_nanqinlang
tee -a /etc/modules-load.d/tcp-cong.conf <<< tcp_tsunami
tee -a /etc/modules-load.d/tcp-cong.conf <<< tcp_bbrplus
tee -a /etc/modules-load.d/tcp-cong.conf <<< tcp_bbr1
```

然后任选一个算法作为拥塞算法:

nanqinlang:
```
tee -a /etc/sysctl.conf <<< "net.ipv4.tcp_congestion_control = nanqinlang"
```

tsunami:
```
tee -a /etc/sysctl.conf <<< "net.ipv4.tcp_congestion_control = tsunami"
```

bbrplus:
```
tee -a /etc/sysctl.conf <<< "net.ipv4.tcp_congestion_control = bbrplus"
```

bbr1:
```
stee -a /etc/sysctl.conf <<< "net.ipv4.tcp_congestion_control = bbr1"
```

成功后，重启即可:

```
sudo reboot
```

---

## BBRv3 (bbr3) 多版本内核 backport

把 Google 树的 BBRv3 拥塞控制算法（`tcp_bbr3.c`）移植为可在**主线/厂商内核**上编译运行的
out-of-tree 模块。已在以下内核树上完成"探测 → 生成 → 编译"全流程验证（零编译告警）：

| 内核 | 构建 | 符号审计 |
|---|---|---|
| 5.4.302 | ✅ | 全部未定义符号均为内核 EXPORT |
| 5.10.261 | ✅ | 同上 |
| 5.15.212 | ✅ | 同上 |
| 6.1.178  | ✅ | 同上 |
| 6.6.145  | ✅ | 同上 |

### 文件清单

| 文件 | 说明 |
|---|---|
| `tcp_bbr3.c` | BBRv3 主源码（已按兼容层修正） |
| `bbr_compat.h` | 兼容层：只消费 `kernel_config.h` 的 `HAVE_*` 宏 |
| `kapi_checklist` | 探测清单（每行一段 C 代码 + 对应的 HAVE_ 宏） |
| `gen_kconfig.py` | 探测器：逐条把探测代码编成内核模块试编译，生成 `kernel_config.h` |
| `Makefile` | 一键构建（先探测、后编译） |
| `audit_symbols.sh` | 可复现的符号审计：核对 .ko 全部未定义符号均为内核 EXPORT |

### 构建 bbr3

```bash
# 本机当前内核（需要已安装 kernel headers / build 目录）
make

# 指定内核树（必须先 make defconfig && make modules_prepare）
make KDIR=/path/to/linux

# 交叉编译
make KDIR=/path/to/linux ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
```

`make` 会先运行 `gen_kconfig.py`，针对 `kapi_checklist` 里的每个 API 在目标内核上
试编译一个小模块：能编译就在 `kernel_config.h` 里 `#define HAVE_XXX 1`，否则留空。
随后编译 `tcp_bbr3.ko`。安装：`sudo insmod tcp_bbr3.ko`，然后
`sysctl -w net.ipv4.tcp_congestion_control=bbr3`。

> **探测验证的边界**：probe 只证明"该 API 在目标内核的头文件里可编译"（存在性+签名），
> 不证明符号可供模块链接（`KBUILD_MODPOST_WARN=1` 会放过未导出符号）。符号解析由
> 最终模块构建的严格 modpost 把关；在无 `Module.symvers` 的树上可用
> `./audit_symbols.sh <内核树>` 做等价核对。

> 如果目标内核树从未完整编译过（没有 `Module.symvers`），modpost 会把
> vmlinux 常驻符号误报为 undefined；加 `KBUILD_MODPOST_WARN=1` 可降级为警告，
> 不影响编译判断。

> **切换目标内核后请重新生成探测结果**：`kernel_config.h` 是针对某一棵内核树生成的，
> 换 `KDIR`/`ARCH` 前执行 `make distclean`（或删除 `kernel_config.h`）再构建。

### 为什么不走 LINUX_VERSION_CODE

发行版/厂商内核会随意 backport 新 API（例如 Ubuntu 5.15、openEuler 5.10），
按版本号猜特性一定会在某些边界上猜错。本方案按"目标内核实际能不能编译这段代码"
来判定特性有无。在原脚本基础上做了：

- 探测清单从 22 条扩到 47 条（补齐 PLB、`delivered_ce`、`tcp_snd_cwnd*`、
  `get_random_u32_below`、`__tcp_send_ack`、`tcp_bbr_info` V2、`cong_control` 四参签名等）；
- 修复 `struct sk_buff skb = {0}` 传值 bug（`TCP_SKB_CB` 需要指针，原探测恒失败）；
- 探测构建加 `KBUILD_MODPOST_WARN=1`（否则未完整编译的树因缺
  `Module.symvers` 全灭）；
- 输出按清单顺序确定性排列；跳过注释/空行；失败时 debug 打印完整编译输出。

### 关键适配设计

1. **`struct bbr`（约 200B）放不进 `icsk_ca_priv`（主线一律 104B）**
   `icsk_ca_priv` 里只存一个指针，`bbr_init()` 里 `kzalloc(GFP_ATOMIC)` 分配，
   `bbr_release()` 释放；所有回调入口带 NULL 防护。

2. **`rate_sample` 新字段**（`lost` / `tx_in_flight` / `is_ece` 等，仅 Google 树有）
   通过宏按探测结果降级：`lost → losses`（语义相同）、`tx_in_flight →
   prior_in_flight`（近似）、`is_ece → delivered_ce > 0`（6.1+）或 `false`。

3. **ECN**：主线的 `ecn_flags` 没有 `TCP_ECN_LOW`（低阈值路由属性，Google 树专有）。
   新增模块参数 `ecn_low`（默认 0，与上游"无 ecn_low 路由"行为一致；**加载期只读 0444**，
   用 `modprobe tcp_bbr3 ecn_low=1` 或 `insmod tcp_bbr3.ko ecn_low=1` 设置）：
   置 1 时注册 op 会带 `TCP_CONG_NEEDS_ECN`，所有 bbr3 连接协商 ECN、
   打 ECT(0) 并接收 CE 事件（dctcp 风格），BBRv3 的 ECN 响应逻辑随之启用。
   只读是因为 ops flags 在注册时一次性确定，运行时改参数会让栈行为与算法判断脱节。

4. **`icsk` 无 `tso_segs` 回调时**（主线只有语义不同的 `min_tso_segs`）
   `bbr_tso_segs()` 不编译、不注册；`bbr_tso_segs_goal()` 仍参与 cwnd/量化预算计算。
   在 linux-zen 等带该扩展的树上探测成功后会自动恢复编译与注册。

### 主线上的功能取舍（相对 Google 树）

| 特性 | 5.4~5.15 | 6.1 | 6.2~6.6 | zen/Google 树 |
|---|---|---|---|---|
| 核心算法（STARTUP/DRAIN/PROBE_BW/PROBE_RTT） | ✅ | ✅ | ✅ | ✅ |
| 丢包驱动 inflight_hi 下调（按轮次） | ✅ | ✅ | ✅ | ✅ |
| skb 级精确丢包定位（`skb_marked_lost`） | ❌ 无此回调 | ❌ | ❌ | ✅ |
| TLP 恢复事件（`CA_EVENT_TLP_RECOVERY`） | ❌ 事件不产生 | ❌ | ❌ | ✅ |
| ECN alpha（EWMA of CE 比例） | ✅* | ✅ | ✅ | ✅ |
| 逐 ACK CE 比例反应（`rs->delivered_ce`） | ❌ | ✅ | ✅ | ✅ |
| PLB（Protective Load Balancing） | ❌ | ❌ | ✅ | ✅ |
| 自定义 TSO 突发尺寸（`tso_segs`） | ❌ | ❌ | ❌ | ✅ |
| `fast_ack_mode` | ❌ | ❌ | ❌ | ✅ |
| `ss` 扩展 BBR 信息（mode/phase/version） | ❌ 旧版 5 字段 | ❌ | ❌ | ✅ |

\* 需要 `ecn_low=1` 才会真正标记 ECT/响应 ECN；<6.1 只维护 alpha，不做逐 ACK CE 反应。

> `tx_in_flight` 在主线上用 `prior_in_flight` 近似：数值口径略不同（前者是"被确认包
> 发送时刻的在飞量"，后者是"本 ACK 处理前的在飞量"），仅影响 loss_thresh 的绝对刻度，
> 方向与安全边际一致。

### 已知边界

- 内核下限：需要 4.13+ 的 `struct rate_sample`；实际验证范围 5.4~6.6。更老内核未测试。
- 7.0+ 内核的 `cong_control` 变为四参 `(sk, ack, flag, rs)`（6.x 及更早为二参
  `(sk, rs)`）；探测宏 `TCP_CONGESTION_OPS_CONG_CONTROL_HAS_4_ARGS` 自动适配两种签名。
- `bbr_ece_ack_update()` 是从 `net/ipv4/tcp_dctcp.h` 拷贝的逻辑（该头文件是内核私有，
  模块不可用），依赖 `__tcp_send_ack`（各版本均 `EXPORT_SYMBOL_GPL`）。
- `struct bbr` 分配失败的极端情形（约 200B 的 `GFP_ATOMIC`，syn-ack 软中断上下文无法
  睡眠，不能用 mempool）：连接会处于"半初始化"状态——所有回调 NULL 防护直接返回，
  不会崩溃，但该连接实际没有拥塞控制更新。属已知限制，仅低内存耗尽时触发。
- `tcp_congestion_ops.release` 被设为**必选**：缺它的内核会在编译期报错，而不是运行时
  静默泄漏每连接状态块（该成员自 2.6.12 起存在）。
- 许可证保持 `Dual BSD/GPL`，可使用 GPL-only 导出符号。

### LICENSE

```
GPL-2.0-only
```
