# 萌宝成长 · 儿童成长助手（iOS）

一款记录孩子成长的 iOS 原生应用（SwiftUI），数据只存在手机本机、不上传云端。

## 功能

- **生长记录**：身高 / 体重 / 脚长 / 头围，按日期保存、可编辑删除
- **生长曲线**：纯 Canvas 绘制的百分位带（P3–P97）+ 实测折线
  - 0–5 岁：WHO 生长标准（LMS 法，按性别月龄逐点计算）
  - 5–7 岁：中国 7 岁以下儿童生长发育参照标准
  - 7–18 岁：WS/T 423 身高发育等级评价
  - 生长速度（年化）、18 岁身高预测（靶身高法 / 百分位外推）
- **喂养记录**：睡眠 / 亲喂 / 瓶喂 / 尿布，今日汇总 + 最近 7 天柱状图
- **接种计划**：广东省执行 · 国家免疫规划 2025 版共 22 剂，点击打卡、到期提醒
- **接种门诊**：广东省示范门诊离线列表，可搜索、按城市筛选、打电话、地图打开
- **鞋服尺码**：脚长自动换算中国码 / 欧码 / 内长，身高对应衣服码
- **阶段重点**：按月龄给出育儿关注点，一键加入待办
- **多宝宝**：支持多个孩子档案自由切换
- **数据管理**：JSON 备份 / 恢复、CSV 导出（发给医生看）

## 没有 Mac 怎么编译？

本仓库用 **GitHub Actions 的 macOS 机器**自动编译：

1. 推送代码到 `main`（或手动触发 Actions 里的 *Build IPA*）
2. 构建完成后，在 **Actions → Build IPA → Artifacts** 下载 `MengBao-ipa-unsigned`
3. 得到的是**未签名 IPA**（`MengBao-unsigned.ipa`）

### 装到 iPhone 上（免开发者账号）

未签名 IPA 不能直接安装，需要用你的 Apple ID 重新签名（免费 Apple ID 即可，7 天有效期，到期重签）：

| 工具 | 平台 | 说明 |
| --- | --- | --- |
| [Sideloadly](https://sideloadly.io) | Windows / Mac | 连接 iPhone，拖入 IPA，输入 Apple ID 自动签名安装 |
| 爱思助手 | Windows | 「自签安装」功能，同样输入 Apple ID |
| AltStore | iOS / Mac | 需常驻一台电脑刷新签名 |

> 想要长期有效 / 上架 App Store，需要 Apple Developer Program（$99/年），并在
> `.github/workflows/build-ipa.yml` 中加入证书签名步骤（P12 + 描述文件），
> 欢迎提 issue 一起加。

## 本地开发（有 Mac 时）

```bash
brew install xcodegen
xcodegen generate      # 生成 MengBao.xcodeproj
open MengBao.xcodeproj
```

要求：Xcode 15+，iOS 16.0+。

## 项目结构

```
MengBao/                  SwiftUI 源码
  Models.swift            数据模型（宝宝 / 记录 / 喂养 / 尺码 / 待办）
  Standards.swift         参考数据（WHO LMS、中国标准、疫苗程序、门诊）
  GrowthMath.swift        生长算法（月龄 / 百分位 / 评估 / 预测）
  Store.swift             本机 JSON 持久化仓库
  Theme.swift             颜色与通用组件
  GrowthChartView.swift   生长曲线 Canvas
  HomeView.swift          首页
  GrowthDetailView.swift  曲线详情 + 记录/尺码/待办编辑
  FeedView.swift          喂养
  VaccineView.swift       接种 + 门诊
  HistoryView.swift       历史
  KidViews.swift          宝宝档案
  ProfileView.swift       我的 / 设置 / 导入导出
project.yml               XcodeGen 工程定义
.github/workflows/        GitHub Actions 自动出 IPA
```

## 免责声明

所有生长评估、鞋码换算、接种安排仅为家庭记录与趋势参考，不构成医疗诊断；
孩子的健康问题请以儿科 / 儿童保健科医生和接种门诊的意见为准。
