# 全 64 元高功率发射驱动分析与最小改动实现（Profile 1 版）

日期：2026-11-23
新增驱动：[SetUpP9_4TSICE_All64_HighPower_P1.m](../../verasonics/curing_mode/SetUpP9_4TSICE_All64_HighPower_P1.m)
对应测试：[test_all64_high_power_p1.m](../../tests/test_all64_high_power_p1.m)
改动基准：[SetUpP9_4TSICE_FlashAngles.m](../../VantageNXT-2.3.2-p2/XJD/SetUpP9_4TSICE_FlashAngles.m)

---

## 1. 资料来源、版本核对与可用边界

### 1.1 指定手册目录在本机不可访问
本机检查确认 `AGENTS.md` 指定的 `F:/xwechat_files/wxid_quwpem6vchzg22_3c29/msg/file/2026-10/` 目录不存在（`PathNotFound`）。依据规则，不猜测该路径下三份不同修订版文件的内容，以下全部硬件依据均直接读取自本机仓库内软件包 `VantageNXT-2.3.2-p2/` 随附文档、源码与 `systemInfo.txt`：

| 文档 / 文件 | 实际版本 / 标识符 | 本报告引用依据 |
|---|---|---|
| `Documentation/Vantage NXT System Product Specification.pdf` | **D00108 Rev. L**（SHA-256 与指定基准一致） | §1.4 pp. 8–9，§1.5 Table 4 pp. 10–11，§3.1.2–3.1.8 Tables 6–12 pp. 15–17，§3.2.1 pp. 18–19，§5 p. 24 |
| `Documentation/Vantage NXT System User Manual.pdf` | **D00107 Rev. L**（随包版；指定版为 Rev. K） | §4.2 p. 28，§4.4.1–4.4.2 pp. 28–29，§7 Table 4 p. 36，§9.2 & §13.3–13.4 pp. 44, 50–51，Appendix A pp. 56–58 |
| `Documentation/Vantage NXT System Initial Setup Instructions.pdf` | **D00109 Rev. E**（随包版；指定版为 Rev. D） | §4.3–4.5 pp. 8–10 |
| `Documentation/Application Note - Vantage NXT System Features and Vantage Script Changes.pdf` | **D00112 Rev. D** | §1.3, §1.5, §1.8, §1.11 pp. 3–6，§2.2–2.3 pp. 7–9 |
| `Documentation/Vantage NXT System Release Notes 2.3.2.pdf` | **D00297 Rev. C** | §4 Issue 7160 p. 3，§5 Issues 10404, 7454, 7606 pp. 3–5 |
| `Documentation/HelpText/*.pdf` | 官方单页字段文档 | `TPC.pdf`、`TW.pdf`、`TW/Parameters.pdf`、`TW/sysExtendBL.pdf`、`TW/Bdur.pdf`、`TW/CumOnTime.pdf`、`TW/fluxHVlimit.pdf`、`TW/equalize.pdf`、`TW/clampHoldTimeus.pdf`、`TW/CStates.pdf`、`TX.pdf`、`Receive.pdf`、`Trans/maxHighVoltage.pdf`、`Trans/impedance.pdf`、`Resource/HIFU.pdf`、`Resource/HIFU/externalHifuPwr.pdf`、`SeqControl/command.pdf`、`setTPCProfile.pdf`、`timeToNextAcq.pdf`、`timeToNextEB.pdf`、`stop.pdf`、`noop.pdf` |
| `VantageNXT-2.3.2-p2/systemInfo.txt` | 系统报告（2026-07-26，HW ID `TMWS0204`） | 本机/实验室设备实际授权许可特征 |
| `VantageNXT-2.3.2-p2/Utilities/computeTrans.m`、`computeTXDelays.m` | 软件包工具源码 | `P9-4ULts` 分支（1854–1878 行）与延时计算逻辑（125–160 行） |
| `Example_Scripts/HIFU/SetUpHIFUsystem.m` 等 | 官方纯发射与推进波示例 | 纯 TX 时 `PData`/`RcvBuffer`/`Receive`/`TGC` 最小占位与 `TW.Parameters` 用法 |

### 1.2 系统许可与两档电源约束（关键发现）
从 `VantageNXT-2.3.2-p2/systemInfo.txt`（lines 44–76）可见：
- 主机 `DESKTOP-2D0K4QC`、硬件序列号 `TMWS0204`（SW `2.3.2-p2`、MATLAB R2024a，有效期 `07/17/2026–07/17/2027`）实际授权的 Feature 仅包括：
  `Hardware`、`Simulator`、`Reconstruction`、`Triggers`。
- **`Extended Transmit`（`extendedTx`）与 `HIFU` 均未出现在 `systemInfo.txt` 许可中。**

对照规范手册：
1. **Tier B（TPC Profile 5：Extended Transmit / HIFU，本版不采用）**：
   - D00108 Rev. L §1.4（pp. 8–9）、§1.5（pp. 10–11，Table 4）、§3.2.1（p. 19）明确规定：未经选装和授权 Extended Transmit 或 HIFU 配置时，**不允许使用 TPC Profile 5**；内部成像电源（Profile 1–4）与 Profile 5 对应不同供电路径。
   - 此外，HIFU 外部电源方案主要面向 **0.5–4.5 MHz**（`Resource/HIFU/externalHifuPwr.pdf`）或 **250 kHz–5 MHz**（D00112 Rev. D §1.11 p. 6），而当前 ICE 探头在 `6–6.5 MHz` 附近工作，频段并不匹配。
   - 在未知 10 Fr 导管探头热额定和介电强度的情况下直接强上毫秒级 Profile 5，极易造成探头不可逆热损或击穿。
2. **Tier A（TPC Profile 1：标准成像供电高占空比上限，本版采用）**：
   - D00107 Rev. L §4.4.1（p. 29）说明：TPC Profile 1–4 使用标准低噪声成像供电，不需额外高功率硬件选件与许可，支持 **相对短的脉冲串与较低占空比，长期平均发射功率约 ~10 W 量级**。
   - `TW.pdf` 与 `TW/sysExtendBL.pdf` 规定：波形周期数 **`< 25 cycles`** 时 `sysExtendBL = 0`（走常规 Profile 1–4）；**`>= 25 cycles`** 时标记为 `sysExtendBL = 1` 并指向 Profile 5。

因此，本版高功率驱动明确采用 **TPC Profile 1 + 严格 `< 25 cycles`（20 周期）+ 全 64 元最大半周期占空比（`B = 1.0`）+ 600 μs PRI（~8 W 平均供电）**，确保无需额外未授权许可即可在现有 Vantage NXT 硬件上加载并安全开展台架测试。

---

## 2. 探头身份与参数溯源边界

按用户 2026-11-07 确认，研究对象为 **TINGSN Sonic Eyes 10 标准版**（软件别名 `P9-4ULts`）。所有来自软件的几何与电气参数均属 `existing_code_unverified`，**不代表厂家实测标定或长脉冲安全额定**：

| 参数 | 当前取值 | 来源与状态 |
|---|---|---|
| 软件名称 / 阵型 / 通道映射 | `P9-4ULts`，`type = 0` 线阵，64 元，`connType = 4`，`ConnectorES = 1:64` | `computeTrans.m:1859–1865`，`existing_code_unverified` |
| 阵元宽度 / 中心距 | `0.11 mm` / `0.13 mm`（全孔径跨度 `8.30 mm`） | `computeTrans.m:1866–1867`，`existing_code_unverified` |
| 标称频率 / 带宽 | `6.5 MHz` / `[4, 9] MHz` | `computeTrans.m:1859–1860`，`existing_code_unverified` |
| 俯仰孔径 / 固定焦距 | `2.02 mm` / `30 mm` | `computeTrans.m:1870–1871`，源码注释为估计值（`assumed`） |
| 等效负载阻抗 | `50 Ω` 标量 | `computeTrans.m:1877`，`existing_code_unverified`（非宽带复阻抗标定） |
| 软件高压上限 | `Trans.maxHighVoltage = 35 V` | 原 `SetUpP9_4TSICE_FlashAngles.m:49`，`existing_code_unverified`（**不是**长脉冲安全额定） |
| 允许长脉冲 / 占空比 / 累计负荷 / 温升接口 | 未知 | `unknown`（热敏电阻读取未在本驱动启用；且 D00108 Rev. L §1.4 p. 8 明确系统检查只保护主机，不保护探头或限制声输出） |

---

## 3. 高功率参数设计与电气 / 时序 / 功率预算

驱动顶部集中管理 7 个可调 `assumed` 发射参数（除 `startDepth`/`endDepth` 外）：

- `P.focusMm = 20`：沿用 2026-11-19 确定的全 64 元 20 mm 目标距离，`TX.focus = 20 / (1.54 / 6.5) = 84.4156 wavelengths`。
- `P.steerDeg = 0`：与 2026-11-19 偏转聚焦方向兼容，支持不变更延时算法即可按 `TX.Steer = [P.steerDeg*pi/180, 0.0]` 做固定 20 mm 直线距离平面内偏转（`computeTXDelays.m:141–147`）。
- `P.txFreqMHz = 6`：沿用原脚本发射频率 6 MHz。
- `P.halfCycleDuty = 1.0`：由原 `0.67` 提升至 `1.0`（与官方 `SetUpL7_4PushTest.m:90` 及 `SetUpL7_4ShearWaveImaging.m:123` 一致）。对称三电平方波基波幅值正比于 $\sin(\pi B / 2)$：`B = 1.0` 相比 `B = 0.67`（$\sin(0.335\pi)=0.8686$），**基波电压提高 15.12%，基波声功率提升约 32.53%**。
- `P.txCycles = 20`（`C = 40` 半周期）：严格小于 25 周期阈值（计及默认 `TW.equalize = 1` 首尾均衡脉冲仍满足 `< 25` 周期，`sysExtendBL = 0`），包络时长 `3.3333 μs`，与仓库既有三维 k-Wave 全 64 元 20 周期仿真一致。
- `P.priUs = 600`：PRI = `600 μs`（满足 D00108 Rev. L §5 p. 24 规定的 `10–4,190,000 μs`），留足 `TX.Delay`（~`3.5 μs`）+ `TW` + 硬件开销（`2–5 μs`）。
- `P.numPulses = 500`：有限 500 发（约 `0.300 s`）后 `stop` 冻结；在 VSX 中切换 Freeze 按钮即可精确重放下一组 500 发。
- `TPC(1).maxHighVoltage = 35`（不突破原 35 V 上限），但 **`TPC(1).hv = 1.6`（安全最低启动电压）**：开机上机或测试时由操作者在 VSX 界面确认负载、耦合和温度后再手动逐级升压。

### 3.1 500 MHz 时钟量化与硬件器件限值核对（假设 35 V、50 Ω 负载）

1. **半周期脉宽与脉间恢复（D00108 Rev. L Tables 8–9, p. 16）**：
   - 6 MHz 理论半周期 `83.333 ns`，500 MHz 时钟（2 ns/tick）量化后约为 `42` 时钟 = `84 ns`（实际约 `5.952 MHz`），完全处于中频模块 `2–1000` 时钟（`4 ns–2 μs`）范围内；
   - 异极性半周期紧邻交替，同极性脉冲间隔约为 `84 ns > 10 ns`（5 时钟），满足同极性脉冲恢复时间要求。
2. **变压器磁通饱和（D00108 Rev. L Table 7, p. 16）**：
   - 在 `35 V`、`84 ns` 半周期下，单半周期伏微秒积分 $\approx 35 \times 0.084 = 2.94\text{ V}\cdot\mu\text{s}$，远低于中频模块 `67 V·μs` 限值（余量 > 22 倍）。
3. **峰值电流与连续 RMS 电流（D00108 Rev. L Tables 10–12, p. 17）**：
   - 按原软件 `50 Ω` 负载 + 系统内阻 `5 Ω`（纯阻上界 $R_{\text{total}} = 55\ \Omega$；若计及 $0.4\ \mu\text{H}$ 感抗 $X_L = 15.08\ \Omega$，总阻抗模值 $|Z| = 57.03\ \Omega$，电流与功率更小）：
   - 35 V 下峰值电流上界 $I_{\text{pk}} = 35 / 55 = 0.6364\text{ A} < 2\text{ A}$（Table 11）；
   - 计及默认均衡脉冲（约 41 个等效半周期，`41/12 μs = 3.4167 μs`；量化 `41 × 0.084 = 3.444 μs`），占空比 `0.5694%`（量化 `0.5740%`），单通道 RMS 连续电流 $I_{\text{rms}} = 0.6364\sqrt{0.005694} = 0.0480\text{ A RMS} \ll 0.4\text{ A RMS}$（Table 12）。

### 3.2 三版驱动关键参数与假设功率对照表（均按假设 35 V、50 Ω 负载估算）

> 注意：以下电流、电功率与电能量均基于 `existing_code_unverified` 50 Ω 负载与理想方波模型估算，**不代表实测值、声功率、温升或固化效果**；原成像脚本自身未写 `TPC.hv`（软件缺省启动 1.6 V），仅下表“35 V 对照”用于等压对比脉冲与占空比差异。

| 指标 | 原成像基线 `SetUpP9_4TSICE_FlashAngles.m` | 2026-11-20 纯 TX 版 `TXOnly_20mm_35V_offline.m` | 本版高功率 Profile 1 `All64_HighPower_P1.m` |
|---|---|---|---|
| 阵元数 / 焦点 | 全 64 元 / 虚拟顶点发散波（15 角） | 全 64 元 / 固定 `[0,0,20]` mm | 全 64 元 / `[0,0,20]` mm（支持 `P.steerDeg`） |
| 波形 `TW.Parameters` | `[6, 0.67, 2, 1]`（1 周期） | `[6, 0.67, 2, 1]`（1 周期） | **`[6, 1.0, 40, 1]`（20 周期，`sysExtendBL=0`）** |
| 启动电压 / 上限 | 未设（缺省 `1.6 V`） / `35 V` | 直接请求 `35 V` / `35 V` | **`1.6 V` 安全起步 / `35 V` 上限（VSX 可调）** |
| 发射时序 | 15 次/组 × 30 组，组内 400 μs，组末 14400 μs（`jump` 循环） | 同左 450 次后 `stop` | **`600 μs` PRI × 500 次（0.300 s）后 `stop`** |
| 单脉冲包络 / 有效 ON 时长 | `0.1667 μs` / `0.1117 μs`（不含均衡）；`0.1675 μs`（含均衡） | 同左 | **`3.3333 μs`（包络）；`3.4167 μs` / 量化 `3.444 μs`（含均衡）** |
| 全序列 ON 占空比 | `0.0125%`（包络）/ `0.00838%`（不含均衡）/ `0.01256%`（含均衡） | 同左 | **`0.5556%`（包络）/ `0.5694%`（含均衡）/ `0.5740%`（量化）** |
| 64 通道脉冲期电源功率（35 V） | `1425.45 W`（纯阻上界）；基波有效功率受 `B=0.67` 折减 | 同左 | `1425.45 W`（纯阻上界）；**基波功率较 `B=0.67` 高 `32.53%`** |
| 64 通道时间平均电源功率（35 V） | `0.1194 W`（不含均衡）/ `0.1791 W`（含均衡） | 同左 | **`7.919 W`（包络）/ `8.117 W`（含均衡）/ `8.182 W`（量化，约 ~10 W Profile 1 包络内）** |
| 平均功率提升倍数（vs 原 35 V，不含/含均衡） | 基线（`1×`） | `1×` | **`~66.33×`（包络比不含均衡）/ `~45.33×`（均含均衡）；叠加 `B=1.0` 基波增益更高** |
| 64 通道单次运行名义电能量（35 V） | `0.0716 J`（450 发不含均衡）/ `0.1074 J`（含均衡） | 同左 | **`2.376 J`（500 发包络）/ `2.455 J`（量化含均衡）** |
| 64 通道 1.6 V 启动默认平均功率 | `~0.00025–0.00037 W` | `N/A`（直接 35 V） | **`~0.0166–0.0171 W`**（适合无负载/示波器初查） |

---

## 4. 代码最小改动对照表

| 模块 | 相对 `SetUpP9_4TSICE_FlashAngles.m` 的处理方式 | 依据与说明 |
|---|---|---|
| `Resource.Parameters` | **几乎原样保留**，仅将 `simulateMode` 改为 `1` | 保持 128 TX/RX、`speedOfSound=1540` 等定义；默认离线不自启硬件 |
| `Trans` | **完全原样保留** | 保留 `'P9-4ULts'`、`wavelengths`、`computeTrans(Trans)`、`maxHighVoltage=35`、`id=-1` |
| `TPC(1)` | **最小新增 2 行**（`maxHighVoltage=Trans.maxHighVoltage`, `hv=1.6`） | 显式锁死 Profile 1 上限在 `35 V`，且以最低安全压 `1.6 V` 启动 |
| `P` 参数块 | 保留 `startDepth`/`endDepth`/`theta`/`rayDelta`/`aperture`/`radius`，新增 7 行 `P.*` 高功率参数 | 删除 `na`/`dtheta`/`startAngle` 多角度扫角变量 |
| `PData(1)`、`TGC` | **原样保留**（1 个 `PData` 与 `computeRegions`、`TGC` 与 `computeTGCWaveform`） | 按官方纯 TX 示例 `SetUpHIFUsystem.m:68–92` 保持 VSX 加载器结构完整性 |
| `Resource.RcvBuffer(1)` & `Receive` | **最小精简为 1 帧 × 1 项未调度占位**（`rowsPerFrame=4096`，`callMediaFunc=0`） | `4096` 为 128 整数倍（D00297 Rev. C Issue 10404）；仅供 VSX loader 检查，`Event.rcv` 全为 `0` |
| `TW` | 保留 `type='parametric'`，改 `Parameters=[P.txFreqMHz, P.halfCycleDuty, 2*P.txCycles, 1]` | `[6, 1.0, 40, 1]`，仅改占空比 `1.0` 与半周期数 `40` |
| `TX` | 由 15 元数组精简为 **1 项**，`focus` 改用 `P.focusMm` 换算，`Steer` 用 `P.steerDeg`，调原厂 `computeTXDelays(TX)` | 保持全 64 元 `Apod=ones(1,64)` 与原厂延时公式 |
| `SeqControl` & `Event` | 精简为 `timeToNextAcq(P.priUs)` + `stop`；500 次纯 TX 事件（`rcv=0, recon=0, process=0`）后 `stop` | 删除 `transferToHost`（避开 Issue 7454 崩溃）与 `jump` 死循环 |
| 纯成像对象与回调 | **移除** `Media`、`InterBuffer`、`ImageBuffer`、`DisplayWindow`、`Recon`、`ReconInfo`、`Process`、`UI` 及回调函数、`VSX;` 自动调用 | 纯发射驱动不执行成像重建与显示；由用户审查后手动加载 `VSX` |

---

## 5. 台架启用与安全约束

1. **禁止直接对生物样品或未耦合探头满压运行**：本脚本默认 `simulateMode = 1` 且 `TPC(1).hv = 1.6 V`，严禁未经验证直接改为 `simulateMode = 0` 并拉高至 `35 V`。
2. **建议上机排查顺序**：
   - 先在离线 `simulateMode = 1` 下通过 `VSX` 加载 `SetUpP9_4TSICE_All64_HighPower_P1`，确认无错误或 `sysExtendBL`/限值告警；
   - 接入 `50 Ω` 假负载或未插探头（如适用）核对示波器实际脉冲宽度、20 周期波形、600 μs PRI 与 `1.6 V → 5 V → ...` 逐级升压的电压塌陷；
   - 接入水耦合条件下的实支探头后，从低电压逐步提升并同步监测水听器声压与探头头端温度（如外接热电偶或独立测温；TINGSN 资料声称标准版有头端温度传感器，但 Vantage 连接映射在本脚本尚未接入）。
3. **跨电脑路径**：`VantageNXT-2.3.2-p2/` 不随 Git 同步；在接有实际 Vantage 主机且具备对应 MATLAB R2024a 与合法激活的电脑上运行本脚本，应在激活后的 `VantageNXT-2.3.2-p2/` 根目录运行或将其复制到 `VantageNXT-2.3.2-p2/` 对应实验目录后执行，再手动运行 `VSX`。

---

## 6. 本轮实际检查与未执行项

- **已核对**：
  - 厂商基线四文件 SHA-256 与 `results/curing_only_2026-11-03/vendor_hashes_before.json` 完全一致，`VantageNXT-2.3.2-p2/` 未被修改；
  - 读取 `systemInfo.txt`、四份核心随包文档及相关 `HelpText` PDF，核对 `SetUpP9_4TSICE_FlashAngles.m`、`computeTrans.m`、`computeTXDelays.m`、`computeRegions.m`、`computeTGCWaveform.m`、`SetUpHIFUsystem.m`、`SetUpL7_4PushTest.m`；
  - 对新增脚本执行结构与语法审计（括号配对、参数范围、`simulateMode = 1`、`txCycles < 25`、无 `VSX`/`transferToHost`/`jump` 自动调用）。
- **未执行（不得宣称通过）**：
  - **MATLAB 单元测试与静态检查（`tests/test_all64_high_power_p1.m`）未在本机成功运行**：本机调用 `E:\MATLAB\bin\matlab.exe` 在启动阶段触发 MathWorks 许可错误 `5201`（`无法与 MathWorks 服务通信`），未获得 MATLAB 运行结果；须在联网或已激活的 MATLAB 图形会话 / 目标实验机上单独运行验证；
  - **未运行 VSX、hardware/Simulator 加载与实物发射**：无真实负载电压、声压、温升或固化验证结论。
