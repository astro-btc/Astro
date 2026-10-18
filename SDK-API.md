# Astro SDK 接口文档

本文档主要说明 `ASTRO SDK API` 相关接口的调用方式。 代码参考 [demo](./sdk-demo.js)

## 0. 设置API KEY
// API Key - 需要先在账户->开发者代码通过「set api-key ***」设置API KEY, 随机数长度12-32，仅数字和大小写字母
// ⚠️ 如果api key被黑客盗取，黑客就可以开单了，切记谨慎保管，定期更换，长度尽量长

[生成随机数网址](https://astro-btc.github.io/random/)


## 1. 接口概览

- 请求方式：`POST`
- Pair 管理接口：`/xxx/api/config/sdk-update-pair`
- Message 发送接口：`/xxx/api/config/sdk-send-message`
- Profit 查询接口：`/xxx/api/config/sdk-get-profit`
- astro-core 运行状态：`/xxx/api/config/sdk-get-status`
- astro-core 启动 / 重启 / 停止：`/xxx/api/config/sdk-start`、`/xxx/api/config/sdk-restart`、`/xxx/api/config/sdk-stop`
- Pair 接口示例完整地址：`https://127.0.0.1:12345/xxx/api/config/sdk-update-pair`
- Message 接口示例完整地址：`https://127.0.0.1:12345/xxx/api/config/sdk-send-message`
- Profit 接口示例完整地址：`https://127.0.0.1:12345/xxx/api/config/sdk-get-profit`
- Pair 接口支持动作：`list`、`add`、`update`、`delete`
- Message 接口支持类型：`warning`、`notice`

其中 xxx 是指astro主页面的后缀，也就是astro-server/.env 文件中的ADMIN_PREFIX字段

说明：

- `sdk-update-pair` 是统一入口接口，通过请求体中的 `action` 区分具体操作。
- `list` 不需要传 `pair`。
- `add`、`update`、`delete` 需要传 `pair` 对象。
- `sdk-send-message` 用于发送文本消息，通过请求体中的 `type` 区分 `warning` 和 `notice`。
- `sdk-get-profit` 用于查询利润汇总和分页明细，查询参数放在 JSON 请求体中，不需要 `action`。
- `sdk-get-status`、`sdk-start`、`sdk-restart`、`sdk-stop` 均发送 JSON 请求体 `{}`，并按第 3 节对实际请求路径和请求体签名。
- SDK 接口使用下述 API Key 签名，无需登录 Cookie、CSRF 或设备证明。

## 2. 访问限制

- 限频：`20次/10s`
- 限频维度：按客户端 IP 统计
- 超限响应：HTTP `429`

超限返回示例：

```json
{
  "code": -1,
  "message": "The rate limit has been reached."
}
```

## 3. 鉴权与签名

### 3.1 请求头

每次请求都需要带上以下请求头：

| Header | 必填 | 说明 |
| --- | --- | --- |
| `Content-Type` | 是 | 固定为 `application/json` |
| `x-timestamp` | 是 | 当前毫秒时间戳 |
| `x-nonce` | 是 | 随机字符串，建议每次请求唯一 |
| `x-sign` | 是 | 请求签名 |

### 3.2 API Key

服务端需要先配置 API Key。若未配置，会返回：

```json
{
  "code": -1,
  "message": "please run「set api-key xxx」in dev code"
}
```

### 3.3 时间戳要求

- `x-timestamp` 必须是毫秒时间戳
- 与服务端时间误差不能超过 `30 秒`
- 超出范围会返回 HTTP `401`

失败示例：

```json
{
  "code": -1,
  "message": "bad x-timestamp, please adjust your time!"
}
```

### 3.4 Nonce 要求

- 格式：`12-64` 位
- 允许字符：大小写字母、数字、`_`、`-`
- 同一个 `nonce` 不能重复使用，否则会被判定为重放请求

重放请求返回示例：

```json
{
  "code": -1,
  "message": "replay detected"
}
```

### 3.5 签名算法

签名算法：

- `HMAC-SHA256`
- HMAC 密钥：`API Key`
- 输出格式：小写十六进制字符串

其中 `payload` 的构造规则如下：

- `list`：`{"action":"list"}`
- `add`：`{"action":"add","pair":{...}}`
- `update`：`{"action":"update","pair":{...}}`
- `delete`：`{"action":"delete","pair":{...}}`
- `warning`：`{"type":"warning","text":"..."}` 
- `notice`：`{"type":"notice","text":"..."}`
- 利润查询：`{"pageSize":200,"page":1,"year":2026,"month":10}`，也可以用 `{}` 查询当前月

签名消息使用如下 canonical message：

```text
${timestamp}\n${nonce}\nPOST\n${apiPath}\n${rawBody}
```

字段说明：

- `timestamp`：请求头中的 `x-timestamp`
- `nonce`：请求头中的 `x-nonce`
- `POST`：当前接口固定为 `POST`
- `apiPath`：完整请求路径，必须包含实际的 `ADMIN_PREFIX`，例如 `/xxx/api/config/sdk-update-pair`、`/xxx/api/config/sdk-send-message` 或 `/xxx/api/config/sdk-get-profit`；如有查询字符串也必须原样包含
- `rawBody`：请求体原始 JSON 字符串，签名前后必须完全一致

注意：

- 服务端基于原始请求体 `rawBody` 验签，不会将解析后的对象重新序列化后再计算签名。
- 客户端必须先构造最终请求 JSON 字符串，再对这个字符串签名，然后把同一份字符串作为 HTTP Body 发出。

Node.js 示例：

```js
const crypto = require('crypto');

function signRequest(apiKey, nonce, timestamp, apiPath, rawBody) {
  const canonicalMessage = [
    String(timestamp),
    String(nonce),
    'POST',
    apiPath,
    rawBody
  ].join('\n');

  return crypto
    .createHmac('sha256', String(apiKey))
    .update(canonicalMessage)
    .digest('hex');
}
```

## 4. 请求/响应格式

### 4.1 Pair 接口请求体

统一结构：

```json
{
  "action": "list | add | update | delete",
  "pair": {}
}
```

说明：

- 当 `action = list` 时，不需要 `pair`
- 当 `action = add/update/delete` 时，必须传 `pair`

### 4.2 Message 接口请求体

统一结构：

```json
{
  "type": "warning | notice",
  "text": "要发送的字符串"
}
```

说明：

- `type = warning` 时，服务端会写入：`[uiw]-` + `text`
- `type = notice` 时，服务端会写入：`[uin]-` + `text`
- `text` 必须是非空字符串，服务端会做 `trim()`

### 4.3 成功响应

成功时业务码为：

```json
{
  "code": 0
}
```

不同动作的 `data` 不同，下面分别说明。

### 4.4 失败响应

常见失败格式：

```json
{
  "code": -1,
  "message": "错误信息"
}
```

## 5. Pair 对象字段

`add` 和 `update` 使用的 `pair` 对象，至少应包含下面这些常用字段。

| 字段 | 类型 | 是否常用必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `string` | `update/delete` 必填 | 10 位字母数字 ID |
| `name` | `string` | 是 | 交易对名称，如 `ETH` |
| `type` | `string` | 是 | 支持 `SF`、`FF`、`SR`、`FR`、`FS` |
| `status` | `boolean` | 是 | 是否启用 |
| `openPosition` | `string` | 是 | 开仓阈值 |
| `closePosition` | `string` | 是 | 平仓阈值 |
| `disableOpen` | `boolean` | 是 | 是否禁开仓 |
| `disableClose` | `boolean` | 是 | 是否禁平仓 |
| `maxTradeUSDT` | `string` | 是 | 最大交易额度，要求 `>= 10` |
| `leverage` | `string` | 是 | 杠杆 |
| `independentLeverageSide` | `string` | 否 | 单腿合约杠杆覆盖侧，`a` 或 `b`；必须与 `independentLeverage` 同时传入，且所选腿必须是合约 |
| `independentLeverage` | `string` | 否 | 单腿合约杠杆倍数，正整数字符串 |
| `buyEx` | `string` | 是 | 买入交易所 |
| `sellEx` | `string` | 是 | 卖出交易所 |
| `aMarketSymbol` | `string` | 否 | A 腿实际交割合约 symbol，例如 `BTCUSDT_260925`；OKX U 本位交割格式如 `ETH-USD_UM-261225`；仅合约腿可用，创建后不可修改 |
| `bMarketSymbol` | `string` | 否 | B 腿实际交割合约 symbol；支持 Binance、Bybit、OKX、Gate（Bitget 无 U 本位交割，不支持） |
| `startTime` | `string` | 否 | 启动时间 |
| `minNotional` | `string` | 否 | 最小名义价值，若传则要求 `>= 6` |
| `maxNotional` | `string` | 否 | 最大名义价值，若传则要求 `>= minNotional` |
| `stopLoss` | `string` | 否 | 止损参数 |
| `rateMultiply` | `string/number` | 否 | 额外倍率参数 |
| `stepOpen` | `array` | 否 | 梯度开仓配置 |
| `stepClose` | `array` | 否 | 梯度平仓配置 |
| `priceAlert` | `string/number` | 否 | 价格告警参数 |
| `adjustParams` | `object` | 否 | 动态调整参数 |
| `usdcNoTrade` | `boolean` | 否 | 部分类型可用 |
| `spotMarginType` | `string` | 否 | `FS` 类型可传：`spot`、`cross`、`isolated` |

更新已启用独立杠杆的卡片时，SDK 必须继续携带这两个字段；同时省略表示关闭并清除独立杠杆。

说明：

- `add` 时服务端会自动生成 `id`，客户端可不传。
- `update` 时必须传合法 `id`，否则返回 `bad pair id for update`。
- `delete` 时只需要 `pair.id` 即可，但传完整对象也不会影响签名。
- 示例脚本里的 `pair` 是最基础、最常用的一组字段，不代表全部可选字段。

## 6. 接口明细

### 6.1 查询列表

用于获取当前所有 `pair` 配置。

列表保留策略配置顺序，单张新增的卡片排在列表开头。

请求体：

```json
{
  "action": "list"
}
```

成功响应示例：

```json
{
  "code": 0,
  "data": [
    {
      "id": "Ab12Cd34Ef",
      "name": "ETH",
      "type": "SF",
      "status": false,
      "openPosition": "0.0158",
      "closePosition": "0.0022",
      "disableOpen": false,
      "disableClose": false,
      "maxTradeUSDT": "1000",
      "leverage": "1",
      "buyEx": "binance",
      "sellEx": "binance",
      "startTime": "0",
      "minNotional": "12",
      "maxNotional": "30"
    }
  ]
}
```

### 6.2 新增 Pair

用于新增一个新的 `pair` 配置。注意新增pair会导致astro-core进程重启，因此此动作完成后需要等待3秒再执行其他动作。

新增成功后，页面将卡片显示在所有非置顶卡片的最前面，已有置顶卡片仍优先显示。

请求体示例：

```json
{
  "action": "add",
  "pair": {
    "name": "ETH",
    "status": false,
    "type": "SF",
    "openPosition": "0.0158",
    "disableOpen": false,
    "closePosition": "0.0022",
    "disableClose": false,
    "maxTradeUSDT": "1000",
    "leverage": "1",
    "buyEx": "binance",
    "sellEx": "binance",
    "startTime": "0",
    "minNotional": "12",
    "maxNotional": "30"
  }
}
```

成功响应示例：

```json
{
  "code": 0,
  "data": null
}
```

说明：

- 服务端会自动生成 `pair.id`
- 如果名称重复、字段不合法或参数校验失败，会返回 HTTP `400`

### 6.3 更新 Pair

用于更新已有 `pair`。

请求体示例：

```json
{
  "action": "update",
  "pair": {
    "id": "Ab12Cd34Ef",
    "name": "ETH",
    "status": true,
    "type": "SF",
    "openPosition": "0.0188",
    "disableOpen": true,
    "closePosition": "0.0033",
    "disableClose": false,
    "maxTradeUSDT": "1200",
    "leverage": "1",
    "buyEx": "binance",
    "sellEx": "binance",
    "startTime": "0",
    "minNotional": "15",
    "maxNotional": "40"
  }
}
```

成功响应示例：

```json
{
  "code": 0,
  "data": null
}
```

失败示例：

```json
{
  "code": -1,
  "message": "bad pair id for update"
}
```

### 6.4 删除 Pair

用于删除已有 `pair`。

最小请求体示例：

```json
{
  "action": "delete",
  "pair": {
    "id": "Ab12Cd34Ef"
  }
}
```

成功响应示例：

```json
{
  "code": 0,
  "message": "pair deleted"
}
```

失败示例：

```json
{
  "code": -1,
  "message": "pair id not found for delete"
}
```

### 6.5 发送 Warning/Notice 文本

用于向服务端发送一条文本消息。

服务端收到后会自动转换为：

- `warning` -> `addWarning('[uiw]-' + text)`
- `notice` -> `addWarning('[uin]-' + text)`

Warning 请求体示例：

```json
{
  "type": "warning",
  "text": "「测试」⚠️飞书报警消息"
}
```

Notice 请求体示例：

```json
{
  "type": "notice",
  "text": "「测试」飞书通知消息"
}
```

成功响应示例：

```json
{
  "code": 0,
  "data": null,
  "message": "warning accepted"
}
```

或：

```json
{
  "code": 0,
  "data": null,
  "message": "notice accepted"
}
```

失败示例：

```json
{
  "code": -1,
  "message": "Invalid type parameter."
}
```

```json
{
  "code": -1,
  "message": "bad text param: must be a non-empty string"
}
```

### 6.6 查询利润

请求：`POST /xxx/api/config/sdk-get-profit`。复用后台 `GET /xxx/api/config/get-profit?pageSize=200&page=1&year=2026&month=10` 的查询能力和返回格式，SDK 使用 JSON 请求体及第 3 节的签名方式。

请求体示例：

```json
{
  "pageSize": 200,
  "page": 1,
  "year": 2026,
  "month": 10
}
```

所有参数均可省略，使用默认值时仍需发送 JSON 请求体 `{}` 并对其签名。

| 参数 | 类型 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `page` | `number` | `1` | 页码，从 1 开始；无效值或小于 1 时使用默认值 |
| `pageSize` | `number` | `20` | 每页数量，最大 1000，超过时按 1000 处理；无效值或小于 1 时使用默认值 |
| `year` | `number` | UTC+8 当前年份 | 查询年份 |
| `month` | `number` | UTC+8 当前月份 | 查询月份，1–12 |
| `day` | `number` | `0` | 0 表示整月；1–31 表示指定日期，须与年月对应 |
| `sortBy` | `string` | 不传 | 仅支持 `profit`；默认按结算时间倒序 |
| `sortOrder` | `string` | 不传 | `asc` 或 `desc`；仅与 `sortBy: "profit"` 同时传入有效值时按利润金额排序 |

成功响应示例：

```json
{
  "code": 0,
  "data": {
    "todayProfit": 12.5,
    "todayProfitModify": 0,
    "monthlyProfit": 120,
    "monthlyProfitModify": 5,
    "totalProfit": 1000,
    "totalProfitModify": 20,
    "total": 1,
    "pageSize": 200,
    "page": 1,
    "data": [
      {
        "coinName": "ETH",
        "type": 0,
        "exchangeA": "binance",
        "exchangeB": "okx",
        "profit": 12.5,
        "remark": "",
        "startTime": 1790985600000,
        "time": 1790989200000
      }
    ]
  }
}
```

返回字段说明：

- `todayProfit`：UTC+8 今日利润；传入 `day` 时为指定日期利润。
- `monthlyProfit`：所选年月利润；`totalProfit`：全部历史累计利润，均不受分页影响。
- `todayProfitModify`、`monthlyProfitModify`、`totalProfitModify`：对应范围内的手动调整金额，已包含在对应利润汇总中，无需再相加。
- `total`：所选月份或日期的明细总数；`page`、`pageSize`：实际使用的分页参数；`data`：当前页明细。
- 明细 `type`：`0=SF`、`1=FF`、`2=SR`、`3=FR`、`4=FS`、`5=SS`、`100/101=A/B 边费率盈亏`、`200=手动调整`。
- `exchangeA`、`exchangeB`：交易所名称；`profit`：该条记录利润；`remark`：备注。
- `startTime`：第一笔已成交开仓订单的提交时间，仅有有效值时返回；`time`：利润结算时间，均为毫秒时间戳。
- `id`：仅手动调整记录（`type=200`）返回。

需要 astro-core 处于运行并连接状态；未连接时返回 HTTP `400`、`message: "请点击「启动」按钮!"`，等待 core 响应超过 5 秒时返回 HTTP `400` 超时错误。本接口复用现有 core 协议，无需修改 astro-core。

### 6.7 查询 astro-core 运行状态

请求：`POST /xxx/api/config/sdk-get-status`，请求体为 `{}`。

成功响应示例：

```json
{
  "code": 0,
  "data": {
    "status": 1
  }
}
```

`status` 与 config 根接口一致：PM2 状态为 `online` 时返回 `1`，其他状态或进程尚未注册时返回 `0`。本接口直接查询 PM2，无需 astro-core 建立连接。

### 6.8 启动、重启、停止 astro-core

以下接口均使用 `POST`，请求体为 `{}`，鉴权和限流与其他 SDK 接口相同。

| 接口 | 说明 |
| --- | --- |
| `/xxx/api/config/sdk-start` | 启动 astro-core；已在线时直接成功，`data` 为 `"already running"` |
| `/xxx/api/config/sdk-restart` | 重启已注册的 astro-core 进程 |
| `/xxx/api/config/sdk-stop` | 停止 astro-core |

成功响应：`{"code":0,"data":null}`。操作逻辑复用后台 `/start`、`/restart`、`/stop`；首次尚未注册进程时使用 `sdk-start`。启动或重启成功表示 PM2 操作完成，业务连接就绪仍需等待。

以上进程接口发生 PM2 异常时返回 HTTP `500` 和 JSON `{"code":-1,"message":"错误信息"}`；其中 `sdk-start` 在实际启动失败时仍返回 HTTP `400` 和 `message: "start process failed, please check!"`。

## 7. 常见错误码与状态

| HTTP 状态 | 业务码 | 场景 |
| --- | --- | --- |
| `200` | `0` | 请求成功 |
| `400` | `-1` | 参数错误、字段校验失败、ID 不合法、利润查询时 core 未连接或超时、进程启动失败或重启结果中未找到 astro-core |
| `401` | `-1` | 缺少鉴权头、时间戳错误、签名错误、API Key 未配置 |
| `409` | `-1` | `nonce` 重复，触发重放保护 |
| `429` | `-1` | 触发限频：`20次/10s` |
| `500` | `-1` | 利润查询失败、core 返回无效数据或进程接口发生 PM2 异常 |

## 8. 推荐调用顺序

典型流程如下：

1. 调用 `list` 查询当前配置
2. 调用 `add` 新增 `pair`
3. 再次调用 `list` 获取新增后的 `pair.id`
4. 调用 `update` 更新该 `pair`
5. 调用 `delete` 删除该 `pair`
6. 如需推送消息，调用 `sdk-send-message` 发送 `warning` 或 `notice`
7. 如需查询利润，调用 `sdk-get-profit` 获取汇总和分页明细
