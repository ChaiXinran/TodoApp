# 日常 iPhone PWA

本工程独立复制自 ../richang_flutter_starter 0.4.3。用户要求 Flutter Web + PWA，iPhone Safari/主屏幕使用，云端通过 Codemagic 构建。不要修改安卓原工程。Web 数据在浏览器 IndexedDB，图片需持久保存，不能保留临时 blob URL。保持现有五页、蓝色事务/绿色档案/暖黄记录和原图标。首页无随机句子卡，记录无重复说明行。用户明确授权复制及适配；外部发布前需要确定托管账号/站点。

正式托管：GitHub Pages 的 gh-pages 分支，域名 todo.ranyechai.site（Cloudflare 仅 DNS 的 CNAME 指向 chaixinran.github.io）。自定义域名使用 base-href /，不能改成 /TodoApp/。web/CNAME 随构建发布。离线预缓存不得包含 .nojekyll / CNAME / _headers 等托管配置文件，以免托管方不提供这些文件而导致缓存安装失败。main 保留源码，不把用户浏览器备份或验收数据库提交到发布分支。
