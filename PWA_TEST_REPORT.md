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
- Codemagic 配置已完成，云端构建是否执行及 GitHub 上传状态需以实际远端结果为准，不能把本地构建当作云端构建。
- 数据本机保存，不提供自动云同步。首次打开需要联网加载资源；清除网站数据会删除本机记录。导出/恢复入口提供显式备份。

## 证据

本地 `.verification/chrome-result.json`、`webkit-result.json`、`webkit-offline-limitation.json`、`android-source-integrity.json`；文件不提交到公开仓库，其中备份含合成测试记录和图片。

实际浏览器截图在本地 screenshots/：chrome-home、calendar、affairs、records、archive、backup、offline-records；WebKit 对应文件以 webkit- 开头。截图中的 PWA验收记录为专用浏览器测试数据，不含在正式默认数据库中。

构建与运行命令见 README.md 和 codemagic.yaml。正式入口 lib/main.dart，测试入口 tools/web_validation.dart 不可用于发布。
