---
title: "Sinower 关联 Shopify 销售产品的可行性研究"
status: draft
research_mode: brief
question: "Sinower 在保留产品目录与经销商业务的前提下，哪些交易能交由 Shopify 完成，客户数据、安全和履约责任能转移到什么程度？"
audience: "Sinower 业务负责人、网站维护者和实施开发人员"
protocol_version: "1.0"
updated: 2026-11-22
---

# Sinower 关联 Shopify 销售产品的可行性研究

## 决策摘要

**可行。建议保留 Sinower 的产品目录和询价流程，把可直接成交的商品交给 Shopify 结账，把需要核价的设备交给 Shopify 在报价确认后收款。** 第一阶段可以只在少量 SKU 的详情页添加「在线购买」，链接到 Shopify 商品页或购物车。客户在 Shopify 输入收货资料、付款、查看订单及物流。这样 Rails 无需新增交易订单表、复制客户地址或持有 Shopify 后台接口密钥。 [购前链接][S01] · [客户账号][S08] · [物流跟踪][S07]

能转移的是**线上成交的环节与交易数据存储**。现有经销商审批、询价历史、客户留言和员工后台仍由 Rails 管理。销售实体能否收款、设备能否按结账价实际发货、谁负责清关与售后，决定了能有多少商品真正上线。当前可靠的结论是接法可落地，实际可直购的商品占比待用运价、库存及配置数据测定。 [本地询价流程](../../app/controllers/orders_controller.rb#L48-L69) · [中国大陆支付要求][S05] · [国际运输条款][S07b]

## 研究问题与方法

原始问题是「这个网站能否关联 Shopify 销售产品」，以及客户订单隐私、物流、登录和防黑客能力能交给 Shopify 到什么程度。研究从**商品能否标准定价、运费能否在结账前确定、双方是否需要共享客户身份**三条线拆开，帮助决定先试卖什么、用哪个系统处理什么，以及什么条件会阻止上线。

这是针对实际实施决策的研究简报。先检查本地代码和数据模型，再查询 Shopify Help Center、Shopify Dev、平台安全与隐私资料，以及直接相关的监管原文。采用平台官方能力说明，排除以营销推广为主且无法核实功能边界的内容。特意核对可能否定方案的证据，包括经营主体与支付地区、Shopify B2B 套餐、运价限制、商品变体上限、客户数据权限和数据跨境。覆盖结账、商品、支付、履约、身份、隐私、安全七组问题，且每个影响方案取舍的关键命题都有直接出处或显式标注待验证后，停止本轮搜集。平台文档用于判断平台能力，仓库用于判断当前站点，实际门店开通、承运商报价及合规意见另行验证。

## 1. 当前网站距离在线交易还差什么？

| 当前能力 | 源码中的实际行为 | 接入后的分工 |
| --- | --- | --- |
| 分类、筛选、搜索和 SKU 详情 | Rails 管理分类、公开可见状态、规格和多语言产品内容 | 继续作为官网的产品入口和资料库。 |
| SKU 配置 | 每组可选一个已启用选项。询价保存选项名称、型号、加价和币种 | 能稳定计价的组合可制作 Shopify 变体。未定价组合继续询价。 |
| 「订单」 | `Order` 当前保存联系资料、留言和询价明细，只有待处理、已回复状态。该流程未收款、扣库存或分配物流 | 页面使用「询价记录」区分本地记录和已成交订单。Shopify 作为在线交易的主记录。 |
| 经销商 | Devise 登录，Rails 审核、授权，按当前用户读取询价历史 | 第一阶段保留。零售客户用 Shopify 客户账号查看线上订单。 |

源码依据为本地仓库提交 `fdb7299`。 [分类和 SKU 路由](../../config/routes.rb#L77-L95) · [配置与快照](../../app/models/sku_configuration_selection.rb#L7-L32) · [询价写入](../../app/controllers/orders_controller.rb#L48-L69) · [本地状态](../../app/models/order.rb) · [账号与审核](../../app/models/user.rb#L11-L24) · [经销商自己的历史](../../app/controllers/dealer/orders_controller.rb#L3-L12)

这里有两个不同的「订单号」。客户提出购买意向时是 **Sinower 询价编号**，成交后是 **Shopify 订单编号**。一次询价可能没有成交，也可能分为多笔成交。两个编号需要关联时保存可追溯的引用，避免把「已回复」自动等同于「已支付」。

## 2. 能接到什么程度？

| 模式 | 客户怎么走 | Rails 接口与敏感数据范围 | 适用条件 |
| --- | --- | --- | --- |
| **A. 链接到 Shopify** | 官网详情上的「在线购买」打开 Shopify 对应商品页或含商品的购物车 | 只保存 Shopify 店铺、商品链接和必要的变体标识。可不启用 Admin API 或订单回传 | 想快速试卖，SKU 价格、库存、运费都能确定。第一阶段建议从这里开始。 |
| **B. Rails 购物车接 Shopify Checkout** | 官网选好多个商品，Rails 通过 Storefront API 生成 Shopify 购物车与 `checkoutUrl`，浏览器进入 Shopify 结账 | 增加商品映射和购物车会话。仍可让 Shopify 收集结账身份与地址 | 已证明顾客需要在官网连续选购，且有能力处理库存、币种变化和购物车错误。 |
| **C. 报价确认后付款** | 客户在 Rails 询价，员工核对配置、价格、运费及交期，再在 Shopify 制作草稿订单并发付款入口 | 可先全手工，无需 Shopify API。自动化时才接 Admin GraphQL，传必要的成交资料 | 重型设备、定制选配、大宗订货、运费需要人工核定。 |
| **D. 全量搬到 Shopify** | 商品、账号和交易均在 Shopify，官网可作为内容入口或重做 | Rails 可退役部分功能，但要迁移或重建结构化筛选、配置、询价和经销商审批 | 如果以后主要经营标准电商，且验证当前专用功能可以替代，才适合评估。 |

平台支持外站 Buy Button、预填商品与数量的购物车链接和 Storefront Cart API。链接模式优先考虑跳到 **Shopify 商品页**，客户可先核对变体和当前售价；已知组合可直接进入购物车。Shopify 仍会在结账时校验库存、市场、价格和送达条件。草稿订单可经 Shopify 后台发送带结账入口的付款通知，支付后进入正式订单流程。文章中的「付款通知」指 Shopify invoice 流程，税务发票由相应经营主体按实际规则处理。 [Buy Button][S01a] · [购物车链接][S01] · [Storefront Cart API][S02] · [草稿订单付款][S03]

**本项目建议 A 与 C 并行。** 标准 SKU 自助购买，报价型 SKU 保留现有询价，员工核好合同条件后再发付款入口。这个选择可被证据推翻。例如试点发现大多数订单是多商品混购且跳转明显降低完成率，可以转向 B；如果全部目标市场的运费始终需要人工报价，C 可成为唯一购买路径；如果主体无法取得合规收款渠道，三种模式都不能上线真实收款。

### 产品结构如何映射？

- **价格与库存独立的型号**映射到 Shopify `ProductVariant`。存 Shopify 店铺标识、商品和变体 ID、Rails SKU ID、上线状态。SKU 编码用于员工核对；稳定关联使用平台 ID，避免改码或跨店导致错发。
- **有少量确定组合的设备**可映射为 Shopify 变体。例如黑色台面／灰色台面 × 木背板／白背板，形成四种分别定价的组合。当前官方上限为单商品 **3 个选项维度、2,048 个变体**，并需确认所选销售渠道、主题或 App 对大变体数的兼容性。 [Shopify 变体说明][S04]
- **Rails 的配置不是 Shopify 变体的直接等价物。** 文字属性可传规格标签或业务备注，加价必须由可信的 Shopify 变体价格、受控的组件商品、符合条件的应用，或人工确认的草稿订单收费。不要把页面计算的附加费放进 URL 后当作实收金额。涉及组件、组合库存、退款或折扣时需验证整组操作。开发店能跑的某些 `lineUpdate` 定价方式，生产店受 Plus 等条件限制。 [Cart Transform 限制][S04a]
- **价格、库存和运费以 Shopify 确认的结账结果为准。** 手工试点时，Rails 显示与交易一致的商城价，或者入口引导到 Shopify 查看当前价格。需要同步后，按字段设定单向主数据。Rails 管理规格、分类及内容，Shopify 管理可售、成交价格和发货库存。外部系统主导 Shopify 产品数据时，可研究官方 `productSet` 同步能力。 [产品数据同步][S04b]

## 3. 能否在中国主体下实际收款？

可用支付方式取决于**签约主体、Shopify 商店地区、支付渠道审核和拟销售市场**。官网在山东并不能据此判断最终开店公司或收款资格。

- Shopify 的中国大陆专项文档说明，**中国大陆 Shopify Payments 目前是邀请制早期访问**。具备资格的大陆注册主体用于跨境销售，需要验证 WorldFirst 账户，且这一通道不支持大陆境内销售。通用中国商户指南仍把大陆 Shopify Payments 列为不可用，与专项页的例外并读后，实施上不能把它视为普遍可开通。先核对实际店铺是否被邀请，再准备可审核的第三方支付方案。 [大陆专项说明][S05] · [大陆开通要求][S05a] · [中国商户通用指南][S05b]
- 若真实交易主体在香港特别行政区，适用当地条件。官方指南列出主体类型、实际营运、核验资料和结算银行等要求。应由实际运营主体申请，避免仅变更店铺地区。 [中国商户通用指南][S05b]
- 拿到收款审核结果后，确认目标国家的付款方式、客户显示币种、扣款币种、入账币种、手续费与汇兑、单笔金额限制、退款路径、拒付和资金到账时间。大型设备应特别测一笔达到典型金额的支付流程。预算同时计入 Shopify 套餐、第三方支付服务费和适用的平台交易费，再加物流应用与人工成本。报告没有商户报价，不能估算可靠的最终费率。 [国际销售费用][S05c] · [中国商户支付选择][S05b]

**放行条件**是实际门店能用拟议渠道完成目标市场的支付和退款验证。测试模式可用来验流程，它不证明真实主体已获收款资格。 [测试订单][S05d]

## 4. 物流能交给 Shopify 多大程度？

Shopify 可以接收收货地址、展示已配置的运费、记录履约和追踪编号。仓库配货、预约提货、出口报关、实际承运、目的国清关、安装和售后仍需要 Sinower、代理或承运商安排。第三方承运商实时报价和购买物流面单受套餐、发货地点及承运商能力约束，记录跟踪号与购买面单是两个不同功能。 [承运商实时价][S06] · [面单与发货地区][S06a] · [订单跟踪][S07]

| 订单情形 | 推荐接法 | 上线前验证 |
| --- | --- | --- |
| 常规包裹，已有目标市场费率 | 先配置有限地区和明确费率，单地址测试后上线 | 包装后重量和尺寸、偏远区、退货地址、漏配费率和运费过低的情况。 |
| 需要按地址实时报价 | 接实际使用的承运商或运费应用。Shopify 官方第三方实时运价在 Advanced、Plus 可用，Grow 有附加费或年度账单路径 | 实际发货仓、目的地邮编、包装规则、超重、报价服务超时。核对所选应用的支持范围和套餐。 |
| 大件、托盘、海运、专线或需安装 | 先询价，由员工拿到可执行报价后制作草稿订单，或保留合同结算 | 报价有效期、贸易术语、卸货条件、延误和破损责任、拆单与承运商回传格式。 |
| 已发货，有承运商跟踪编号 | Shopify 后台人工登记或三方仓配接入，客户从订单状态页查询 | 无实时轨迹的承运商也应展示正确单号或跟踪链接。整单、部分发货、多个托盘分别核对。 |

DDP（完税后交货）与 DAP（目的地交货）应对照合同及承运商服务明确。DDP 下卖家承担进口费用。采用 DAP 时，应事先说明客户可能收到的进口税费。页面显示了一个运费数字，不足以说明报价包税、包卸货或包安装。需要结账时收进口税费，还应检查目标国家、商品关税分类及承运商实际支持。 [贸易术语与 DDP 标签][S07b]

## 5. 客户在哪里登录，能否用同一账号？

| 人员 | 第一阶段 | 将来何时整合 |
| --- | --- | --- |
| 零售客户 | 用 Shopify 客户账号查看订单。启用该账号模式时，官方支持邮箱一次性验证码。是否强制客户登录由商店设置决定，试点时核对访客购买体验。 | 如果客户确实需要在 Rails 页面查看已买商品，可评估 Customer Account API，通过 Shopify 客户授权读取自己的资料。 |
| 现有 Rails 经销商 | Rails 登录、审核并查看自己的询价。已成交订单从 Shopify 订单入口查看。 | 需要企业目录和合同价时，用审批后的业务流程将其匹配到 Shopify Company、Location 和相应客户身份。 |
| 内部员工 | Shopify 员工账号操作成交订单。Rails 员工账号维护商品内容、询价与审核。两边分别配置权限。 | 建立入职、调岗、离职同步流程。统一企业身份另作项目。 |

这三个任务要分开评估：① 把 Shopify 订单页面链接给用户；② Rails 自定义页面经用户授权查询；③ 让 Rails 和 Shopify 共用登录身份提供方。第一项成本最低。第二项涉及 Customer Account API 的 OAuth 与正确的订单所有权。第三项如果使用 Shopify 客户账号接自有 IdP，官方要求 **Shopify Plus**。当前 Rails Devise 是应用本地登录模块，不能直接充当 Shopify 要求的通用身份提供方。不要复制密码或密码哈希，也避免只靠客户填写的邮箱判定两个账号属于同一人。 [Shopify 客户账号][S08] · [Customer Account API][S09] · [自有身份提供方][S10] · [Rails Devise 配置](../../app/models/user.rb#L11-L14)

**企业采购也有不同深度。** 官方当前说明 Basic、Grow、Advanced、Plus 均已有一些 Shopify B2B 功能，包括企业、目录和账期。标准计划按活跃 B2B 市场计算，最多 3 个活跃目录分配。直接给单个企业／分支分配专属目录，以及部分高级收款功能，如定金要求、部分付款，属于 Plus 能力。先问清经销商需要的是同一市场批发价、每家公司各自的合同价，还是只需要按确认报价付款，再决定是否为 Plus 付费。现有 Rails 的「已批准」不会自动转成 Shopify 企业用户。 [B2B 套餐对照][S11] · [B2B 设置约束][S11a]

## 6. 客户订单隐私能否留在 Shopify？

**可以把 Shopify 成交订单的详细数据主要留在 Shopify 和必要的支付、履约渠道。** 第一阶段让客户在 Shopify 才输入交易联系方式、账单／收货信息，Rails 不导入 Shopify 客户列表，也不接收全量订单。客户通过 Shopify 查看，授权员工在 Shopify 后台办理。处理订单所需的员工、仓库及承运商仍可能接触必要的资料。订单详情留在 Shopify，并不意味着订单对商家匿名。 [客户账号][S08] · [面单所需资料][S06a] · [Shopify 数据处理补充条款][S12]

| 字段或记录 | 推荐存放处 | Rails 处理规则 |
| --- | --- | --- |
| 商品、配置、库存 | Rails 产品资料与 Shopify 可售商品，按字段指定主系统 | 只交换商品标识、公开资料及必要变体。 |
| 卡号、支付验证及结算 | Shopify Checkout 和实际支付服务商 | Rails 不采集、不转发、不写日志。也不自建输入卡号的付款表单。 |
| 成交订单、收货地址、客户联系方式、追踪号 | Shopify，按发货需要提供给仓库或承运商 | 试点不回传。真的需要对账时，仅保存经评估所需的订单引用和状态。 |
| 询价与经销商审核 | Rails | 原记录包含姓名、手机号、邮箱、留言。需要转为成交时，只把开单所需资料输入 Shopify。过去的询价和经销商密码不批量迁。 |
| API 事件、监控与分析 | 各自运维系统 | 存事件编号、处理结果与必要的内部引用。不要默认长期保存包含姓名、电话、地址或完整 checkout URL 的请求体、日志与监控记录。 |

现有资料也需要继续治理。Rails 的询价表单收集联系资料，访问跟踪路径可记录 IP 和用户代理。把成交订单留在 Shopify，不会改变这些本地数据的收集与保存。上线前应把现有询价、访客统计和新增交易流程一并写进数据清单。 [询价字段](../../app/controllers/orders_controller.rb#L126-L128) · [访客跟踪](../../app/controllers/application_controller.rb#L58-L95)

两点容易被忽略。第一，外站进入 Shopify 的推荐使用路径里，**不要用 URL 参数预填姓名、电话或地址**。这类信息容易进入访问日志、分享链接和分析工具。第二，订单 ID、关联键或哈希值只要可与个人重新关联，仍按个人数据管理。Shopify 对应用可读取的订单、客户和识别字段设有受保护数据规则，权限范围和审批方式取决于应用类型及分发方式。即使只需订单状态，也应验证实际接口和所需批准。 [链接支持的参数][S01] · [受保护客户数据][S13]

**隐私责任**由实际处理目的和开通的服务判断。Shopify 的 DPA 规定了其受托处理的场景，Enhanced Services 等情形可能由 Shopify 作为独立的数据控制方处理。接入前应在数据流程图中列出 Shopify、已安装应用、支付方、仓储方和承运商，核对用途、所在地、可访问角色、保存期限、备份，以及查询、更正和删除如何交接。删除客户资料与按适用规定保留交易凭证要分开办理。 [Shopify DPA 与附录 E][S12] · [子处理方][S12a] · [应用隐私回调][S13a]

如业务适用中国个人信息出境规则，需按收集地点、客户性质、收款与承运参与方、数据类别及处理目的核对。网信办规定对为履行个人参与的跨境购物等合同确需出境的信息，有关于出境评估、标准合同或认证的特定豁免条件。B2B 企业合同联系人、营销受众、历史询价的处理不能直接套用这一条；第十条仍要求依法履行出境告知、单独同意及影响评估等义务。若实际面向欧盟客户，还要核对 GDPR 的适用范围、数据最小化、处理方与跨境转移义务。最终判断需要真实主体和数据流，不能只凭店铺地区或网页语言确认。 [中国个人信息保护法，第 38–39、55 条][L01] · [网信办规定，第 5、10 条][L02] · [GDPR，第 3、5、28 条及第五章][L03]

## 7. 安全性能提高多少，Shopify 能防哪些风险？

**最大的收益是缩小 Rails 接触敏感数据和支付流程的范围。** Shopify 声明其服务具备 Level 1 PCI DSS 合规认证及 SOC 2 Type II、SOC 3 报告。平台托管结账让 Rails 不再需要承担自建收款页的相应技术工作。它仍不替 Sinower 维护 Rails 后台、账号、权限、依赖和第三方应用。支付风控给员工审核参考，尤其应在贵重设备发货前复核高风险订单、实际扣款及可追踪的送达证据。 [Shopify Security][S14] · [欺诈分析][S14a]

| 主要风险 | Shopify 可承担的部分 | Sinower 要落实的部分 |
| --- | --- | --- |
| 支付数据被读取 | 托管 checkout，经实际支付渠道完成交易 | 官网无卡号字段；显示正确的官方结账域名；确认支付与退款以 Shopify 后台为准。 |
| 员工账号被盗、越权或误导出 | 提供账号安全和角色设置 | 每人一个账号，对 Shopify 与 Rails 的关键角色启用适当的 MFA、最小权限和离职回收。限制能查看客户、发起退款及导出数据的人。 |
| 自建站或 API 密钥泄露 | Shopify 提供应用鉴权和访问范围机制 | 首期不申请 Admin API。后期需要时按实际安装方式选择授权，凭据仅放服务器密钥库。继续做 Rails 依赖更新、权限回归、备份恢复和日志检查。 |
| 错单、重复发货或伪造付款通知 | Shopify 维护订单、支付与履约状态，能发送事件通知 | 后期引入 Webhook 时，先在服务端验签，再去重排队，按支付和履约状态处理。事件可能重复、乱序或漏达，用定期对账补齐。禁止信任只从浏览器返回的「支付成功」。 |
| 第三方应用及运营数据泄露 | 平台提供店铺 App 管理 | 审核承运、营销、客服、分析应用的数据权限和保留策略，卸载无用应用；用模拟资料验收。 |

现有仓库已配置生产 HTTPS 和 CI 的 Brakeman 扫描。它们是排查和防护的一环，单靠仓库配置无法确认实际部署、员工账号或外部应用的安全状态。第一阶段不做订单 API 回传，将显著减少需要自行维护的接口。若以后接入事件，参考 Shopify 的签名、去重和对账要求，保留手工暂停、凭据撤销和恢复流程。 [现有 HTTPS](../../config/environments/production.rb#L24-L38) · [现有 CI 扫描](../../.github/workflows/ci.yml#L8-L23) · [员工二步验证][S14b] · [应用授权][S16] · [Webhooks][S15]

## 8. 实施路线、验收与研究问题

### 先测通两种订单

1. **挑少量候选**。建议选 3–5 个现有货、规格标准、售价和运费可确定的 SKU，另外选 1 个复杂设备做报价场景。先选一个目标市场和一个实际发货仓。为每个商品记录包装尺寸、重量、库存、变体、可售地区与退货成本。
2. **接标准零售**。Shopify 建可测试的商品和真实映射，Rails 增加按 SKU 开关的「在线购买」。Rails 页面不要求顾客先提交询价联系方式。检查跳转到正确店铺、型号和币种，无效或停用映射回到询价。
3. **接报价收款**。员工在原站完成报价，核实价格、有效期、交期、地址、运费、税费和售后，再用 Shopify 草稿订单发付款入口。草稿链接作为敏感操作入口通过受控渠道传递。改单后复核价格与运费。试点量少时人工对照询价号和 Shopify 订单号。
4. **验收再上线**。走通目标地区可配送、无报价地区、缺货、付款成功／失败、重复提交、取消退款、打包发货、追踪和客户权限。用两位不同客户验证只能看自己的订单。检查浏览器跳转参数、Rails 日志和数据库没有新增成交客户敏感资料。用测试模式和模拟客户；拟上线收款之前再确认实店资格。 [草稿单注意事项][S03] · [测试订单][S05d]
5. **成功后扩量**。如果管理人员开始重复录入大量草稿单，先考虑仅自动创建草稿单。若需要多商品结账，再接 Storefront Cart。只有订单量和客户需求证明状态回传有必要，再加入 Admin API、Webhook 和对账。需要 Plus 的场景单独评估。

未来的 Rails 实现可先有一张轻量的商品映射表，保存 `sku_id`、店铺、`product_gid`、`variant_gid` 和启用状态。零售流直接使用允许名单里的店铺链接。后续可独立扩展询价与 Shopify 草稿单／订单的关系，用唯一业务键防止重复开单，保存成交引用而不是复制整单。产生动态定价、员工自动开单或事件同步时，才需要自定义 Shopify App。限定一店或同一组织，依据官方分发与鉴权条件选择方式，固定并测试 API 版本，分别使用测试店和正式店的凭据。 [应用分发][S16a] · [鉴权方式][S16] · [草稿单 API][S03a]

### 留给业务和技术团队的可验证问题

| 问题 | 怎么测 | 怎样影响决策 |
| --- | --- | --- |
| **到底有多少商品能直购？** | 用「价格已批准、库存可信、可送达、运费可确定、可售后」筛每件候选 SKU，同时统计它们在历史询价中的占比。 | 能直购的商品比重低时，优先保留报价收款。比例应由数据得出。 |
| **哪些市场能实际收款并赚钱？** | 用真实经营主体核对渠道审批；用一组目标邮编实测运费。计算每单净额，扣除商品、运费、税费承担、支付费、换汇、售后及拒付成本。 | 只上通过收款及毛利门槛的市场。销售量不足时先控制固定套餐与同步开发成本。 |
| **报价后的支付能减少多少重复录入？** | 对照现有流程与草稿订单试点，记录处理时间、改单次数、付款转换、重复开单、漏登记和客户反馈。 | 先手工。需要自动化时，以实测节省时间和减少差错作依据。 |
| **客户真的需要统一登录吗？** | 观察客户询价和下单是否频繁跨系统；访谈经销商真实任务，记录能否从 Shopify 自助找到订单。 | 只有独立登录造成明显阻碍时，才做客户订单入口整合或 Plus 身份方案。 |
| **哪些人必须看到订单隐私？** | 用工作人员角色演练发货、退款、客服和数据查删；逐项说明每个字段为什么要访问或存一份。 | 能在 Shopify 完成的工作保留在那里。只加有业务理由的回传字段。 |
| **发生故障能否安全停下来？** | 在测试店验证链接停用、库存变化、运价失败、登录超时，后期再做事件延迟、重复和对账演练。 | 任何影响金额、身份或履约且无可控回退的问题，必须在开放该流程前解决。 |

## 结论与证据边界

推荐先做「官网展示＋Shopify 托管结账＋保留询价」的小范围试点。能力层面有充分官方依据。对于标准件，商品、购物车、收款、成交记录和客户查单可以交给 Shopify；对于复杂设备，优先让 Shopify 承接**报价之后**的付款与订单记录。物流实物履约、经销商权限、接入安全和隐私责任仍要落实到经办方。若主体或运费过不了实店验证，就限制线上可售商品与市场，保留询价。当前尚未测得可直购比例、真实费率、运价、账户权限和实际部署安全配置。

## 证据表与复查路径

| 证据组 | 阅读的记录 | 用于判断与限制 |
| --- | --- | --- |
| 本地代码 | `fdb7299` 的 routes、OrdersController、配置与用户模型、经销商后台及生产配置 | 判断现站能做什么。未用真实客户资料，也未据此审计线上设置。 |
| Shopify Help Center、Shopify Dev | [S01–S04 结账和配置][S01]、[S05–S07 收款与履约][S05]、[S08–S11 身份与套餐][S11] | 平台的功能及限制，时效性较高。中国商户两份官方资料需要并读；店铺资格用实店验证。Dev 文档的 latest 页面会上移版本。 |
| Shopify 合同、安全及数据文档 | [DPA][S12]、[受保护字段][S13]、[安全说明][S14]、[Webhooks][S15] | 判断职责和接口边界。平台安全声明适用于其服务范围，不能当作 Sinower 或第三方应用的审计。 |
| 正式监管文本 | [中国个人信息保护法][L01]、[网信办数据出境规定][L02]、[GDPR][L03] | 判断需要核查的问题与例外条件。未判定某个实际主体、市场或数据流是否适用特定条款。 |

### 查询记录

日期为 2026-11-22，时区 Asia/Shanghai。通过网络搜索访问 Shopify Help、Shopify Dev、Shopify Legal、安全页及监管网站。未使用独立市场调查样本。搜索引擎未提供可靠总命中数。以下为主要执行查询及跟进阅读路径。

| 主题 | 主要查询原文 | 最有决策价值的跟进 |
| --- | --- | --- |
| 购买入口 | `site:shopify.dev shopify cart permalinks Storefront API cart checkoutUrl Buy Button` | 打开购物车链接、Storefront Cart 管理及 Buy Button 说明。 |
| 商品和人工报价 | `site:help.shopify.com/en/manual/products/variants 2048 3 options Shopify`；`site:help.shopify.com/en/manual/fulfillment/managing-orders draft orders send invoice checkout link custom shipping` | 跟进变体限制、Cart Transform、草稿单付款与 `draftOrderCreate`。 |
| B2B 和账号 | `site:help.shopify.com/en/manual/b2b plans basic grow advanced plus features Shopify`；`site:help.shopify.com/en/manual Shopify customer accounts one-time code order status own identity provider plus` | 对照套餐表、企业设置、自有 IdP 和 Customer Account API。 |
| 收款 | `site:help.shopify.com Shopify Payments supported countries China mainland Hong Kong third-party payment` | 阅读中国通用说明，再跟随专项页的 Requirements 链接核实邀请、跨境用途和 WorldFirst。 |
| 物流 | `site:help.shopify.com/en/manual shipping rates carrier calculated shipping third-party plan international duties DDP Shopify`；`site:help.shopify.com Shopify add tracking number third party fulfillment after ship shipping labels eligible countries China merchant` | 区分实时运费、购买面单、发货和跟踪，核对支持地区与套餐。 |
| 隐私 | `site:shopify.com/legal Shopify DPA merchant customer personal data disclosure subprocessors`；`site:shopify.dev customer account api protected customer data webhooks privacy compliance` | 阅读 DPA 附录 E、子处理方、客户数据等级与 App Store 隐私回调。 |
| 数据出境 | `site:gov.cn 个人信息保护法 第三十八条 跨境 site:cac.gov.cn 促进和规范数据跨境流动规定 跨境购物`；`site:eur-lex.europa.eu regulation 2016 679 GDPR article 5 28 44 minimisation controller processor` | 打开网信办法规原文及市场监管总局转载法律原文，对照 EUR-Lex 正式文本。不采用检索结果中的第三方解读作为法条。 |
| 安全和对账 | `site:shopify.com security Shopify PCI DSS Level 1 two step authentication Shopify`；`site:shopify.dev webhook HMAC duplicate Shopify webhook event id reconciliation best practices` | 区分平台认证范围、员工权限和自定义应用义务，确认重复、乱序与补偿对账边界。 |

### 披露

本报告由 AI 辅助检索、阅读源码和起草。平台能力、条件及法规均可用下方原始链接复查。报告未开店、未安装 App、未使用真实客户资料或发起交易。正式实施应以实际门店、签约主体、物流线路及相关专业意见复核。

[S01]: https://shopify.dev/docs/apps/build/checkout/create-cart-permalinks
[S01a]: https://help.shopify.com/en/manual/online-sales-channels/buy-button
[S02]: https://shopify.dev/docs/storefronts/headless/building-with-the-storefront-api/cart/manage
[S03]: https://help.shopify.com/en/manual/fulfillment/managing-orders/create-orders/send-draft
[S03a]: https://shopify.dev/docs/api/admin-graphql/latest/mutations/draftOrderCreate
[S04]: https://help.shopify.com/en/manual/products/variants/add-variants
[S04a]: https://shopify.dev/docs/api/functions/latest/cart-transform
[S04b]: https://shopify.dev/docs/apps/build/product-merchandising/products-and-collections/sync-data
[S05]: https://help.shopify.com/en/manual/payments/shopify-payments/supported-countries/china
[S05a]: https://help.shopify.com/en/manual/payments/shopify-payments/supported-countries/china/requirements
[S05b]: https://help.shopify.com/en/manual/intro-to-shopify/initial-setup/sell-in-china/set_up_payments
[S05c]: https://help.shopify.com/en/manual/international/pricing/fees
[S05d]: https://help.shopify.com/en/manual/checkout-settings/test-orders/processing-test-order
[S06]: https://help.shopify.com/en/manual/fulfillment/setup/shipping-rates/third-party-carrier-calculated-shipping
[S06a]: https://help.shopify.com/en/manual/fulfillment/fulfilling-orders/shipping-labels/understanding-shipping-labels
[S07]: https://help.shopify.com/en/manual/fulfillment/setup/order-status-page/order-tracking
[S07b]: https://help.shopify.com/en/manual/international/duties-and-import-taxes/carriers-and-shipping-terms
[S08]: https://help.shopify.com/en/manual/customers/customer-accounts/index
[S09]: https://shopify.dev/docs/api/customer/latest
[S10]: https://help.shopify.com/en/manual/customers/customer-accounts/sign-in-options/identity-provider/connect
[S11]: https://help.shopify.com/en/manual/b2b/getting-started/plan-features
[S11a]: https://help.shopify.com/en/manual/b2b/getting-started/considerations
[S12]: https://www.shopify.com/legal/dpa
[S12a]: https://help.shopify.com/en/manual/privacy-and-security/privacy/subprocessors
[S13]: https://shopify.dev/docs/apps/launch/protected-customer-data
[S13a]: https://shopify.dev/docs/apps/build/compliance/privacy-law-compliance
[S14]: https://www.shopify.com/security
[S14a]: https://help.shopify.com/en/manual/fulfillment/managing-orders/protecting-orders/fraud-analysis
[S14b]: https://help.shopify.com/en/manual/your-account/users/security/two-step-authentication
[S15]: https://shopify.dev/docs/apps/build/webhooks
[S16]: https://shopify.dev/docs/apps/build/authentication-authorization
[S16a]: https://shopify.dev/docs/apps/launch/distribution
[L01]: https://www.samr.gov.cn/wljys/gzzd/art/2023/art_3ef1e889c1e644d4b65b5f5c7f432386.html
[L02]: https://www.cac.gov.cn/2024-03/22/c_1712776611775634.htm
[L03]: https://eur-lex.europa.eu/legal-content/ENG/ALL/?uri=celex%3A32016R0679
