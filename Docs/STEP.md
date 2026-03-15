# 梯度开清示例

### 1. 对于 SF(现期)， FF(期期)模式
示例 (可以直接复制或编辑后复制， 在Astro开单页面导入即可)：

```
ASTRO-QUICK-COPY:
{
  "type": "SF",
  "name": "ETH",
  "openPosition": "10",
  "closePosition": "-10",
  "maxTradeUSDT": "3000",
  "buyEx": "binance",
  "sellEx": "binance",
  "leverage": "4",
  "minNotional": "20",
  "maxNotional": "60",
  "startTime": "0",
  "disableClose": false,
  "disableOpen": false,
  "stopLoss": "",
  "stepOpen": [
    {
      "position": 0.01,
      "limit": 1000
    },
    {
      "position": 0.02,
      "limit": 2000
    },
    {
      "position": 0.03,
      "limit": 3000
    }
  ],
  "stepClose": [
    {
      "position": 0.02,
      "limit": 2000
    },
    {
      "position": 0.01,
      "limit": 1000
    },
    {
      "position": 0,
      "limit": 0
    }
  ]
}
```

### 2. 对于 SF(现期)， FF(期期)模式
示例 (可以直接复制或编辑后复制， 在Astro开单页面导入即可)：

```
ASTRO-QUICK-COPY:
{
  "type": "SR",
  "name": "BTC-USDC",
  "openPosition": "0",
  "closePosition": "Infinity",
  "maxTradeUSDT": "5000",
  "buyEx": "binance",
  "sellEx": "binance",
  "leverage": "4",
  "minNotional": "20",
  "maxNotional": "60",
  "startTime": "0",
  "rateMultiply": "1",
  "disableClose": false,
  "disableOpen": false,
  "stopLoss": "",
  "stepOpen": [
    {
      "position": 72000,
      "limit": 1000
    },
    {
      "position": 71500,
      "limit": 2000
    },
    {
      "position": 71000,
      "limit": 3000
    },
    {
      "position": 70500,
      "limit": 4000
    },
    {
      "position": 70000,
      "limit": 5000
    }
  ],
  "stepClose": [
    {
      "position": 70500,
      "limit": 4000
    },
    {
      "position": 71000,
      "limit": 3000
    },
    {
      "position": 71500,
      "limit": 2000
    },
    {
      "position": 72000,
      "limit": 1000
    },
    {
      "position": 72500,
      "limit": 0
    }
  ]
}
```


