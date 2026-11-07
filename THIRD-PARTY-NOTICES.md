# Third-Party Notices

本仓库构建时会从 Maven Central 下载以下第三方构件（仅用于编译期 `compileOnly`，不进入最终 APK）：

## libxposed-api

- **坐标**: `io.github.libxposed:api:102.0.0`（`.aar`，内含 `classes.jar`）
- **来源**: https://github.com/libxposed/api · https://central.sonatype.com/artifact/io.github.libxposed/api
- **许可证**: Apache License 2.0
- **版权**: Copyright (c) LSPosed developers and contributors
- **用途**: `ModuleMain` 编译时的 `compileOnly` 依赖（`io.github.libxposed.api.XposedModule` 等 API 类）。APK 内不包含这些类，运行时由 LSPosed 框架提供。
