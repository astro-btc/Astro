# Astro SDK 接口文档

本文档主要说明 `ASTRO SDK API` 相关接口的调用方式。 代码参考 [demo](./sdk-demo.js)

## 0. 设置API KEY
// API Key - 需要先在账户->开发者代码通过「set api-key ***」设置API KEY, 随机数长度12-32，仅数字和大小写字母
// ⚠️ 如果api key被黑客盗取，黑客就可以开单了，切记谨慎保管，定期更换，长度尽量长

## 1. 接口概览

- 请求方式：`POST`
- 接口地址：`/api/config/sdk-update-pair`
- 示例完整地址：`https://127.0.0.1:12345/api/config/sdk-update-pair`
- 支持动作：`list`、`add`、`update`、`delete`

说明：

- 这是一个统一入口接口，通过请求体中的 `action` 区分具体操作。
- `list` 不需要传 `pair`。
- `add`、`update`、`delete` 需要传 `pair` 对象。

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

签名消息使用如下 canonical message：

```text
${timestamp}\n${nonce}\nPOST\n${apiPath}\n${rawBody}
```

字段说明：

- `timestamp`：请求头中的 `x-timestamp`
- `nonce`：请求头中的 `x-nonce`
- `POST`：当前接口固定为 `POST`
- `apiPath`：固定为 `/api/config/sdk-update-pair`
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

## 4. 通用请求/响应格式

### 4.1 请求体

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

### 4.2 成功响应

成功时业务码为：

```json
{
  "code": 0
}
```

不同动作的 `data` 不同，下面分别说明。

### 4.3 失败响应

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
| `buyEx` | `string` | 是 | 买入交易所 |
| `sellEx` | `string` | 是 | 卖出交易所 |
| `startTime` | `string` | 否 | 启动时间 |
| `minNotional` | `string` | 否 | 最小名义价值，若传则要求 `>= 8` |
| `maxNotional` | `string` | 否 | 最大名义价值，若传则要求 `>= minNotional` |
| `stopLoss` | `string` | 否 | 止损参数 |
| `rateMultiply` | `string/number` | 否 | 额外倍率参数 |
| `stepOpen` | `array` | 否 | 梯度开仓配置 |
| `stepClose` | `array` | 否 | 梯度平仓配置 |
| `priceAlert` | `string/number` | 否 | 价格告警参数 |
| `adjustParams` | `object` | 否 | 动态调整参数 |
| `usdcNoTrade` | `boolean` | 否 | 部分类型可用 |
| `spotMarginType` | `string` | 否 | `FS` 类型可传：`spot`、`cross`、`isolated` |

说明：

- `add` 时服务端会自动生成 `id`，客户端可不传。
- `update` 时必须传合法 `id`，否则返回 `bad pair id for update`。
- `delete` 时只需要 `pair.id` 即可，但传完整对象也不会影响签名。
- 示例脚本里的 `pair` 是最基础、最常用的一组字段，不代表全部可选字段。

## 6. 接口明细

### 6.1 查询列表

用于获取当前所有 `pair` 配置。

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

## 7. 常见错误码与状态

| HTTP 状态 | 业务码 | 场景 |
| --- | --- | --- |
| `200` | `0` | 请求成功 |
| `400` | `-1` | 参数错误、字段校验失败、ID 不合法 |
| `401` | `-1` | 缺少鉴权头、时间戳错误、签名错误、API Key 未配置 |
| `409` | `-1` | `nonce` 重复，触发重放保护 |
| `429` | `-1` | 触发限频：`20次/10s` |

## 8. 推荐调用顺序

典型流程如下：

1. 调用 `list` 查询当前配置
2. 调用 `add` 新增 `pair`
3. 再次调用 `list` 获取新增后的 `pair.id`
4. 调用 `update` 更新该 `pair`
5. 调用 `delete` 删除该 `pair`

如果你希望，我还可以继续把这份文档补成：

- `curl` 调用示例版
- 前端/Node.js SDK 示例版
- 更偏给客户看的精简中文版
