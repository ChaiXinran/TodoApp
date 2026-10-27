# 日常 · iPhone PWA 0.5.0

基于 Flutter Web 的独立 iPhone 版本，云端通过 Codemagic 构建。保留首页、日历、事务、记录、档案五个页面，以及原有配色、插画和猫兔心情。源自安卓 0.4.3，安卓原工程独立保留。

## 正式地址与发布

正式地址：**https://todo.ranyechai.site/**。GitHub Pages 使用 gh-pages 分支，main 保留源码；Cloudflare 的 todo CNAME 指向 chaixinran.github.io，使用仅 DNS。首次发布需等待 DNS 生效和 GitHub HTTPS 证书签发。此域名使用根路径 /，不要使用 /TodoApp/ 作为 base-href。

## 在 iPhone 使用

用 Safari 打开部署后的固定 HTTPS 网址，选择“分享 → 添加到主屏幕 → 添加”。之后从主屏幕进入。首次联网加载并完成资源缓存后可以离线使用。此版本是 PWA 网站，不是 IPA，不需要 Mac、Xcode 或苹果开发者签名。

数据只存于当前设备/网址的 IndexedDB，不自动同步到安卓或其他设备。右上角“使用与备份”可导出全部数据和图片，也可确认后恢复。请把备份保存到“文件”或其他可靠位置；清除网站数据或更换域名会影响本机数据访问。浏览器持久存储请求不等于云备份。

## 内置课表

使用用户最新截图：11 门课程、13 条上课安排，含思想政治实践与社会实践（未排课）；周四风险理论为单周，保险风险计量与 R 为双周。学期共 18 周，周六周日无课。

用户确认 **2026-10-27 为第10周周二**，故第1周周一为 **2026-08-24**。没有具体作息时间，按节次展示；如需调整开学日期，可在“使用与备份”设置。用户已取消课表文件导入功能。

## 本地构建

Flutter **3.47.8** / Dart **3.13.7**；Python 3 用于准备和校验运行资源。

```sh
python3 tools/prepare_assets.py
flutter pub get
dart compile js -O2 tools/sqlite_worker.dart -o web/sqflite_sw.js
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
python3 tools/prepare_pwa.py
```

产物 `build/web/` 是完整静态网站。使用 HTTPS 托管；本地开发的 localhost 也可以运行 service worker。部署到子路径时使用 `flutter build web --base-href /子路径/ ...`。不可只发送 HTML 文件或通过 file:// 打开。

## Codemagic 云端构建

源码已上传仓库；项目已在 Codemagic 建立。当前平台页面在 HTTP 400 / React 错误后空白，云端构建尚未启动；本地验证结果与限制见测试报告。

1. 将此工程作为仓库根目录，连接 `ChaiXinran/TodoApp`。
2. Codemagic 添加应用，选择该仓库、Flutter/YAML 配置，选择 workflow **richang-ios-pwa**。
3. 启动构建。流程会下载并校验开源字体/WASM、安装依赖、运行 analyze/test、编译 worker、打包 Web 和离线缓存。
4. 下载构建产物 **richang-ios-pwa-web.zip**，解压后部署到固定 HTTPS 站点（例如 Cloudflare Pages 或其他静态托管）。

当前 YAML 只构建产物，不包含托管账号的发布凭据，也不会自动公开新的站点。Codemagic 官方说明 YAML 工作流不能直接发布 Codemagic Static Pages；如使用该托管需改用其 Flutter workflow editor，并确保构建后仍运行离线缓存脚本。构建与网站托管是两个步骤。

参考：[Codemagic Flutter 配置](https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/) · [Static Pages 限制](https://docs.codemagic.io/yaml-distributing/publishing-to-codemagic-static-pages/)。

## 数据与资源

SQLite v5，通过 WASM worker 写入 IndexedDB；图片转为 data URI 保存进数据库，刷新后仍可显示。worker 在回复操作成功前等待 IndexedDB flush，避免立即刷新时未落盘。备份恢复整库使用事务；无效备份回滚。WebKit 可申请持久存储，仍需定期备份。

运行文件、字体和插画均在本站加载；自有 service worker 缓存完整发布版本，更新不删除数据库。新版本等待现有窗口关闭后激活。字体 Noto Sans SC 使用 OFL，许可在 assets/fonts/OFL.txt；SQLite worker 许可在 tools/vendor/SQFLITE_LICENSE。

## 验证

见 [PWA_TEST_REPORT.md](PWA_TEST_REPORT.md)。浏览器测试入口 `tools/web_validation.dart` 仅用于专用测试数据库，不包含在线上默认入口中。Windows 浏览器/WebKit 测试不能替代 iPhone 真机验收；Safari“添加到主屏幕”仍需手机最终确认。
