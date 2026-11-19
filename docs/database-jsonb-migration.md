# PostgreSQL / JSONB 本地切换记录

日期：2026-11-19。

## 已完成

- 本地 PostgreSQL 18.4；开发和测试均切换到 PostgreSQL。
- 商品 specifications 从 SQLite 文本 JSON 迁移为 PostgreSQL 原生 JSONB。
- 保留现有数组规格结构，不把它改成新的属性库格式。
- 本地服务停止后，通过 SQLite 在线备份接口生成一致性快照并检查 integrity_check。
- 快照：`db/backups/development-before-postgresql-20261119.sqlite3`，不进入版本库。
- 原 SQLite 数据库与 storage 附件目录保留。
- 从快照复制 30 张应用表，保留 ID、密码散列、富文本、订单、关联及附件引用；不触发应用回调、邮件或任务。
- 每张表对全部字段的规范化内容做 SHA-256 比较和行数核对，全部一致后提交事务。
- 原数据共 732 行，其中分类 106、商品 99、富文本 396、用户 3；附件元数据表原本为空。
- 重置 PostgreSQL 自增序列，避免后续创建记录发生 ID 冲突。
- PostgreSQL 完整回归：43 个测试、212 个断言通过；补充存储迁移专项：2 个测试、9 个断言通过。
- 本地网站已用 PostgreSQL 重启；/up、/products、制冷频道列表均返回 HTTP 200。

## 连接

- 开发：sinower_shandong_development；可用 DEVELOPMENT_DATABASE_URL 覆盖。
- 测试：sinower_shandong_test；可用 TEST_DATABASE_URL 覆盖。
- 生产：继续使用 DATABASE_URL。本次没有生产连接信息，未执行线上迁移。
- 生产部署时先备份，再执行新迁移；已有 JSONB 时不重复转换。

## 导入工具

```sh
bin/rails runner script/import_sqlite_to_postgresql.rb PATH_TO_SQLITE_SNAPSHOT
```

仅允许 development + PostgreSQL + 空目标应用表，导入失败会回滚全部数据。
必须先停止旧服务并备份。不能对已有业务数据的目标库重复执行。
当前项目新建数据库用 db:schema:load；不要从头重放历史迁移来重建旧 SQLite。

## 恢复边界

切换后产生的新数据在 PostgreSQL，旧 SQLite 快照不会自动更新。
需要回退时，先停止服务并用 pg_dump 备份当前 PostgreSQL，再根据切换后的写入情况制定数据回迁。
不要直接把配置改回 SQLite 后继续使用，那会遗漏切换后的新数据。
JSONB 对象不保留键顺序，数组顺序仍保留；原规格使用数组，因此展示顺序保留。
