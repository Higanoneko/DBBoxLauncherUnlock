# 开发文档

面向想了解原理、自己构建或做二次开发的读者。普通用户请看 [README.md](README.md)。

## 实现原理

Dangbei OS 在 `system_server` 的 `PackageManagerService` 里内置了一个私有方法：

```java
private boolean isNotDangbeiLauncher(String packageName)
```

它检查包名是否在 `DANGBEI_LAUNCHERS` / `DANGBEI_CHILD_LAUNCHERS` 两个白名单集合里：

- 在白名单 → 返回 `false`（即"是当贝允许的桌面"）
- 不在白名单 → 返回 `true`

随后 `applyPostResolutionFilter()` 会遍历 HOME intent 的 ResolveInfo 列表，把 `isNotDangbeiLauncher(pkg) == true` 的项全部 `remove` 掉，导致第三方桌面连候选资格都进不去。

本模块在 `onSystemServerStarting` / `onPackageLoaded`（`android` 包）时把 `isNotDangbeiLauncher` hook 为恒返回 `false`，放开全部桌面。

```
applyPostResolutionFilter()
    └─ isNotDangbeiLauncher(pkg)  ← hook 为恒 false
        └─ 原本返回 true ⇒ 该 ResolveInfo 被移除
```

入口：`src/io/github/dbboxlauncherunlock/ModuleMain.java`，`META-INF/xposed/java_init.list` 声明模块入口类，`scope.list` 声明作用域为 `system`。

## 构建

### 前置环境

| 依赖 | 版本 | 覆盖方式 |
|---|---|---|
| JDK | 17+ | `JAVA_HOME` |
| Android SDK build-tools | 37.0.0 | `BUILD_TOOLS` |
| Android SDK platform | android-36 | `ANDROID_JAR` |
| Python 3 | 任意 | `PYTHON` |

`build.ps1` 顶部有默认路径，可直接改或设环境变量。

### 首次构建

```powershell
cd DBBoxLauncherUnlock
.\build.ps1
```

脚本会自动从 Maven Central 下载 `io.github.libxposed:api:102.0.0`（`.aar`），提取 `classes.jar` 到 `deps/`；后续构建离线可用。

### 构建产物

```
out/
├── dbboxlauncher-unlock.apk   # 最终 APK（已签名，可直接 adb install）
├── module-aligned.apk
├── module-unsigned.apk
├── classes.dex / classes.jar
├── classes/            # ModuleMain.class
└── stub-classes/       # 编译期 stub 的 .class（不进 APK）
```

首次运行自动生成 `module.keystore`（`android`/`android`，alias `dbboxlauncher`）并签名；keystore 已 gitignore，**勿提交**。

### 依赖说明

`ModuleMain` 只依赖 `io.github.libxposed.api`（`XposedModule` 等接口）和 `androidx.annotation.NonNull`。前者由 LSPosed 框架在运行时提供，所以构建时仅作 `compileOnly`：

- `deps/libxposed-api-*.classes.jar` —— 编译 classpath 用，**不打包进 APK**
- `stubsrc/` —— `androidx.annotation`、`io.github.libxposed.annotation` 的最小 stub，同样只进 classpath

## 仓库结构

```
DBBoxLauncherUnlock/
├── build.ps1                  # 主构建脚本
├── AndroidManifest.xml        # 模块清单（xposed minApi=101）
├── README.md / Dev.md / LICENSE / THIRD-PARTY-NOTICES.md
├── res/                       # app_name 等资源
├── resources/META-INF/xposed/ # java_init.list / module.prop / scope.list
├── src/io/github/dbboxlauncherunlock/     # ModuleMain.java（模块入口）
├── stubsrc/                   # 编译期 stub 类
└── deps/                      # 依赖缓存（gitignore）
```

## 调试

- LSPosed 日志：`logcat -s LSPosed:*`（模块里用 `log()` 也会进 LSPosed 日志）
- 直接看模块日志：`adb logcat -s DBBoxLauncherUnlock`
- 关键日志：
  - `installHook via <回调名>` —— hook 被触发
  - `hooked isNotDangbeiLauncher OK` —— 成功
  - `hook failed` —— 方法不存在/被混淆（可能固件不匹配）

## 兼容性

- **已验证**：RK3566 / Dangbei OS / Android 11
- `isNotDangbeiLauncher` 是当贝 OS 私有方法，其他品牌/型号大概率不存在；找不到方法时模块仅记录失败日志，不影响系统
- 方法名若被混淆（无规则混淆基本不可能，因 PMS 走 framework）需手动调整 `ModuleMain.java` 里的 `PMS` 常量和方法名
