# README

后台
* ...
sinower网站

全栈技术: ruby on rails

后台主要功能:
3级别身份权限
博客
产品分类管理
产品管理
访客统计
联系信息收集

前台重要功能: 多级别分类自动弹出型导航

## 数据库

开发、测试、生产统一使用 PostgreSQL，商品规格 `skus.specifications` 使用原生 JSONB。
本地默认通过 Unix socket 连接当前系统用户，数据库分别为
`sinower_shandong_development` 和 `sinower_shandong_test`。
需要 PostgreSQL 已启动且当前用户可创建数据库。

```sh
bundle install
bin/rails db:prepare
bin/rails db:test:prepare
bin/rails test
```

可分别设置 `DEVELOPMENT_DATABASE_URL`、`TEST_DATABASE_URL` 覆盖本地连接；
生产继续使用 `DATABASE_URL`。不要把数据库密码提交到仓库。
CI 已配置 PostgreSQL 18 服务。

### 旧 SQLite 数据迁移

原 `db/development.sqlite3` 保留作历史数据，不再作为运行数据库。
`sqlite3` gem 仅供旧数据迁移工具手动加载，应用启动不加载它。
2026-11-19 本地切换记录及恢复说明见 [数据库切换记录](docs/database-jsonb-migration.md)。
全新数据库使用当前 schema 创建；已存在的 PostgreSQL 数据库执行：

```sh
bin/rails db:migrate
```

新增迁移会将原 JSON 列转换为 JSONB；已经是 JSONB 时跳过。
生产执行前先备份；大表类型转换需要安排维护窗口，不能认为零停机。

