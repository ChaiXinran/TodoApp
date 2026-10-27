# iPhone PWA 0.5.0 验证记录

日期：2026-10-27，Asia/Shanghai。

## 已完成

- 独立工程 `richang_ios_pwa`，从安卓 0.4.3 复制。原安卓 lib/assets 共 31 个文件哈希核对未修改（实际数量见本地 `.verification/android-source-integrity.json`）。
- Flutter analyze 无问题；32 项单元/界面测试通过，包含截图课表覆盖、单双周、18 周无重叠，以及小屏大字体、入口配色等原测试。
- Flutter Web Release 实际编译成功；没有用静态网页替代 App。原五页和数据关系保留。
- 已按截图内置 11 门课程、13 条规则，2026-08-24 为第1周周一，2026-10-27 为第10周周二，周末无课。未排课课程保留备注；不开发课表文件导入。
- Chromium 手机尺寸 390×844：五个标签、实际输入标题和选择图片文件、保存 data URI、导出含图片的 JSON、确认恢复、顶部心情弹窗、断网后重新加载记录页通过。
- Chromium 与 Windows WebKit：截图课表计数、待办增改/完成、笔记和图片、心情、目标与两个独立分项、文件夹和关联、句子选择、整库备份恢复、坏备份事务回滚、关闭数据库重开、浏览器刷新持久化通过。
- 修复 worker 在保存回复前未等待 IndexedDB 落盘的问题，补丁放在 tools/vendor/durable_worker.dart；未修改依赖缓存源码，保留 BSD 许可。
- WebKit 也完成了五页、真实输入与文件选择、导出和确认恢复流程；字体及运行资源打包在网站内，开源字体许可随包提供。

## 明确限制与未验收

- Windows WebKit 的离线导航没有通过：缓存里已有首页，service worker 已控制页面，但测试环境断网后 fetch/reload 返回 WebKit internal error。记录在 `.verification/webkit-offline-limitation.json`；不能据此声称 iPhone 离线已通过。Chromium 的相同离线测试通过。
- 未连接真实 iPhone，Safari“添加到主屏幕”、刘海/底部安全区、软键盘、系统文件分享和真实离线重开仍需手机最终验证。
- 某些 WebKit 测试日志有回退字体证书错误，测试不绕过 TLS；中文界面已使用本机打包字体。专用验证入口没有 sw.js，因此其两次 404 不来自正式发布包。
- 已上传 ChaiXinran/TodoApp 的 main 分支，Codemagic 个人项目也已创建并连接公开仓库。但是项目设置页与应用列表在 HTTP 400 / React #31 后持续空白，尚未触发云端构建。当前可部署包是本地实际构建产物，不能当作 Codemagic 云端成功结果。
- 数据本机保存，不提供自动云同步。首次打开需要联网加载资源；清除网站数据会删除本机记录。导出/恢复入口提供显式备份。

## 证据

本地 `.verification/chrome-result.json`、`webkit-result.json`、`webkit-offline-limitation.json`、`android-source-integrity.json`；文件不提交到公开仓库，其中备份含合成测试记录和图片。

实际浏览器截图在本地 screenshots/：chrome-home、calendar、affairs、records、archive、backup、offline-records；WebKit 对应文件以 webkit- 开头。截图中的 PWA验收记录为专用浏览器测试数据，不含在正式默认数据库中。

构建与运行命令见 README.md 和 codemagic.yaml。正式入口 lib/main.dart，测试入口 tools/web_validation.dart 不可用于发布。

## 2026-10-27 正式域名发布

已将发布产物上传 gh-pages 分支并启用 GitHub Pages；Cloudflare 仅 DNS 的 todo CNAME 指向 chaixinran.github.io，GitHub 在 TodoApp 中绑定 todo.ranyechai.site。HTTPS 证书获批并启用强制 HTTPS。

正式 HTTPS 网站返回 200；390×844 浏览器实际检查首页、日历、事务、记录、档案及 11 门截图课程加载成功，PWA manifest 为 standalone。实际线上 service worker 控制页面并缓存完整资源后，断网重开记录页通过；页面错误与网络失败均为 0。此处是 Chromium 线上验收，原 Windows WebKit 离线导航限制与 iPhone 真机待验收仍保留。

证据：本地 .verification/live-site-result.json 与 pages-deployment.json；实际截图 screenshots/live-home.png、live-calendar.png、live-affairs.png、live-records.png、live-archive.png、live-offline.png。

这次只新增 todo.ranyechai.site 对应的发布绑定，未修改主域名或其他子域名的 DNS。main 存源码，gh-pages 存网站产物。最初上传前仓库没有分支和既有源码；本地安卓源文件哈希保持不变。
