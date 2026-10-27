# 日常 · iPhone PWA

这是独立的 Flutter Web/PWA 工程，复制自本地安卓 0.4.3。先读 AGENTS.md 和 README.md，不要编辑旁边的安卓工程。

- iPhone 用 Safari 打开 HTTPS 网址，再“分享 → 添加到主屏幕”。本工程不产生 IPA/APK，不需 Xcode 或 Apple 开发者签名。
- 云端构建使用根目录 codemagic.yaml，workflow `richang-ios-pwa`。
- 依赖资源先运行 `python3 tools/prepare_assets.py`，再 `flutter pub get`。脚本校验字体/WASM 的固定 SHA256；不要关闭 TLS 证书验证。
- `dart compile js -O2 tools/sqlite_worker.dart -o web/sqflite_sw.js` 编译数据库 worker。自有补丁在 tools/vendor/durable_worker.dart，保存应等待 IndexedDB flush 完成。
- `flutter analyze`、`flutter test`、`flutter build web --release --no-web-resources-cdn`，再 `python3 tools/prepare_pwa.py` 生成离线缓存。
- 浏览器数据在 IndexedDB，图片是 SQLite 中持久 data URI；不能换回临时 blob URL。备份和恢复入口在右上角“使用与备份”。恢复须确认并通过事务验证关联，失败回滚。
- 仅内置用户最新截图课表：11 门课程、13 条规则、第1周周一 2026-08-24、18 周，周末无课。不再开发课表文件导入；别复用原安卓学期课表。
- `tools/web_validation.dart` 是专用浏览器测试入口，包含合成记录；不可作为线上入口，线上默认 lib/main.dart。
- 资源缓存更新不清 IndexedDB。已有网页关闭后新 worker 才激活，避免混合版本。保持固定 HTTPS 域名与路径。
