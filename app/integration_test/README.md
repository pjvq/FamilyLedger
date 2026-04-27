# Integration Performance Tests

Flutter 前端性能测试框架，基于 `integration_test` 包 + timeline profiling。

## 前提条件

- 连接真实设备 **或** 运行 iOS/Android 模拟器
- Flutter SDK（与项目版本一致）
- `integration_test` 不支持 headless 运行（需要 GPU）

## 测试文件

| 文件 | 用途 |
|------|------|
| `test_app.dart` | 测试工具 — 绕过登录启动 app |
| `app_performance_test.dart` | 核心性能基准：启动、滚动、Tab 切换 |
| `frame_metrics_test.dart` | 帧率测量：build/raster 时间、jank 统计 |
| `memory_test.dart` | 内存分析：基线、泄漏检测 |

## 运行方式

### 全部运行

```bash
# 从 app/ 目录
flutter test integration_test/ --profile

# 或使用脚本
./scripts/run_perf_tests.sh
```

### 单独运行

```bash
flutter test integration_test/app_performance_test.dart --profile
flutter test integration_test/frame_metrics_test.dart --profile
flutter test integration_test/memory_test.dart --profile
```

### 使用 Makefile（从项目根目录）

```bash
make bench-flutter
```

## 输出格式

### Timeline Data

`traceAction` 生成的 timeline 数据保存在：
```
build/<platform>/timeline_summary.json
```

包含：
- `average_frame_build_time_millis`
- `90th_percentile_frame_build_time_millis`  
- `99th_percentile_frame_build_time_millis`
- `worst_frame_build_time_millis`
- `average_frame_rasterizer_time_millis`
- `missed_frame_build_budget_count`

### Report Data

`reportData` 输出的自定义指标会打印到 stdout 并保存在测试结果中。

## 注意事项

1. **必须用 `--profile` 模式** — debug 模式的性能数据不具参考价值
2. **物理设备 > 模拟器** — 模拟器的帧率受宿主机影响，不够稳定
3. **首次运行较慢** — shader 编译会影响首帧，多跑几次取稳定值
4. **CI 环境** — 需要 macOS runner + 模拟器，或连接的物理设备
5. **内存数据** — 精确堆分析需要 DevTools Memory 面板 + profile mode

## 进阶用法

### 结合 DevTools

```bash
flutter run --profile integration_test/app_performance_test.dart
# 打开 DevTools → Performance 面板查看 timeline
```

### 输出 JSON 结果（适合 CI）

```bash
flutter test integration_test/ \
  --profile \
  --machine \
  > perf-results.json
```

### Shader 预热

如果 shader 编译导致首帧 jank，可以用 `--cache-sksl` 收集 shader：
```bash
flutter run --profile --cache-sksl --purge-persistent-cache
# 操作完后按 M 导出 flutter_01.sksl.json
flutter test integration_test/ --profile --bundle-sksl-path=flutter_01.sksl.json
```
