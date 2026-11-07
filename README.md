# DBBoxAllLauncher

**让当贝盒子（Dangbei OS / RK356x，Android 11）允许安装并设为默认的第三方桌面。**

本仓库即 LSPosed 模块 **DBHomeUnlock**（`me.dbtools.dbhome`）的完整源码与构建脚本。

## 原理

Dangbei OS 在 `system_server` 的 `PackageManagerService` 里内置了一个 `isNotDangbeiLauncher(String)` 检查：只有包名在 `DANGBEI_LAUNCHERS` / `DANGBEI_CHILD_LAUNCHERS` 白名单里的应用才能出现在 HOME intent 的解析结果中；其余桌面（如 Android TV Launcher、Leanback、第三方 Launcher）在 `applyPostResolutionFilter()` 阶段就被直接 `remove` 掉，连候选资格都进不去。

本模块把 `isNotDangbeiLauncher` 恒改为返回 `false`，放开所有桌面。

```
applyPostResolutionFilter()
    └─ isNotDangbeiLauncher(pkg)  ← hook 为恒 false
        └─ 原本返回 true ⇒ 该 ResolveInfo 被移除
```

## 使用方法（LSPosed 模块，推荐）

1. 确保盒子已安装并激活 **LSPosed**（`LSPosed-v2.2.1-7939-release` 等）。
2. 构建或直接获取 `dbhome-unlock.apk`，安装到盒子：
   ```bash
   adb install out/dbhome-unlock.apk
   ```
3. 在 LSPosed 管理器中启用模块，作用域勾选 **Android 系统**（`system`）。
4. 重启盒子或 `adb reboot`。
5. 安装任意第三方桌面即可在“选择主屏幕应用”里使用。

> 注：模块只勾选 `system` 作用域，不会 Hook 其他应用。

## 从源码构建

### 前置环境

- **JDK 17+**（脚本默认指向 `C:\Android\jdk21\...`，可用环境变量 `JAVA_HOME` 覆盖）
- **Android SDK**（默认路径见脚本顶部，可用 `BUILD_TOOLS`、`ANDROID_JAR` 覆盖）
  - build-tools `37.0.0`
  - platform `android-36`
- **Python 3**（用于把 `classes.dex` 和 `META-INF/xposed` 打进 APK；可用 `PYTHON` 覆盖）
- 首次构建会自动从 Maven Central 下载 `io.github.libxposed:api:102.0.0`（`.aar`）并提取 `classes.jar` 到 `deps/`；后续构建离线可用

### 构建模块 APK

```powershell
cd DBBoxLauncherUnlock
.\build.ps1
```

产物：`out\dbhome-unlock.apk`（首次运行自动生成 `module.keystore` 并签名；keystore 已加入 `.gitignore`）

## 仓库结构

```
DBBoxLauncherUnlock/
├── build.ps1                  # 主构建脚本（javac → d8 → aapt2 → apksigner）
├── AndroidManifest.xml        # 模块清单（xposed minApi=101）
├── res/                       # app_name 等资源
├── resources/META-INF/xposed/ # 模块入口 / 作用域 / api 版本声明
├── src/me/dbtools/dbhome/     # 模块源码（ModuleMain.java）
├── stubsrc/                   # 编译期 stub（androidx.annotation / libxposed.annotation）
├── stubsrc/                   # 编译期 stub（androidx.annotation / libxposed.annotation）
└── deps/                      # 构建时自动下载的依赖缓存（libxposed-api classes.jar，已 gitignore）
```

## 兼容性说明

- 仅在 **RK3566 / Dangbei OS (Android 11)** 固件上验证过。
- `isNotDangbeiLauncher` 是该固件特有的私有方法，其他品牌/型号不一定存在；若方法不存在模块会打印 hook 失败日志，不影响系统。
- 通过 `logcat -s [DBHomeUnlock]` 可查看 hook 状态。

## License

Apache License 2.0 — 见 [LICENSE](LICENSE)。

第三方组件声明见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)（vendored `libxposed-api` 代码来自 [libxposed/api](https://github.com/libxposed/api)，同样为 Apache-2.0）。
