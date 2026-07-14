### [Astro产品介绍](./README.md) 
### [Astro安装教程](./INSTALL.md) 
### [Astro常见问题](./Docs/常见问题.md) 
### [Astro安全相关-必读](./SECURITY.md) 

套利策略，产品使用群 \
https://telegram.me/astro_discuss

行情工具 \
https://pulse.astro-btc.xyz/ \
https://astro-btc.github.io/Astro-Perps/?coin=ETH

实时资讯, 上新，费率调整等 \
https://telegram.me/astro_realtime_news

--------------------------------

# Astro - 安装教程

### 1. 云服务器要求
切记不可以使用中国境内服务器，推荐阿里云，亚马逊云香港，日本地区 \
**境外网络完全可以本地部署，交易所KEY需要绑定IP，请注意IP变化**  \
**请不要用美国地区服务器，Bybit不让美国IP使用API** 

操作系统: ```Ubuntu系统``` \
系统架构：```x86-64``` \
内存：```最少2GB``` 

### 2. 执行一键安装脚本 (需确认公网IP地址)， 安装完成后请使用最新版Chrome浏览器打开（其他浏览器会有兼容性问题）
```
curl -L https://raw.githubusercontent.com/astro-btc/Astro/refs/heads/main/install.sh | sudo bash -
```

### 3. astro-server/.env 文件字段说明

| **配置项**               | **说明**                                                        |
|--------------------------|-----------------------------------------------------------------|
| `PORT`                   | 端口号，需要防火墙放行此端口 （默认8443暂不支持修改）                         |
| `ALLOWED_DOMAIN`         | 云服务公网IP地址，也可以填域名（填写域名需替换证书）                   |
| `ADMIN_PREFIX`           | 管理后台访问的 URL 后缀 （请自行更改， 最少4个字符）                             |
| `ADMIN_SECURITY_CODE`    | 登录密码  （登录后，点击头像可修改密码）                                      |
| `ADMIN_2FA_SECRET`       | 二次认证密钥，请导入 Google Authentication 使用 （登录后，点击头像可修改密码）    |


此配置文件修改过后，请重启系统生效 

### 4. 如何配置交易所API？
‼️ 请务必每一个api都添加IP地址白名单 ‼️  \
‼️ 请务必 **不要** 开通[提现]权限 ‼️ 

#### a. Binance
合约账户类型必须是 **统一账户**, 权限相关参考下图：\
（请先调整为统一账户，然后再创建API）
![](images/BN-api.png)

#### b. Bybit
保证金模式设置为： **全仓保证金** \
权限相关参考下图：\
![](images/Bybit-API.png)

#### c. Bitget
支持统一账户 & 经典账户 \
请使用联合保证金模式， 并开启双向持仓，权限相关参考下图：\
![](images/BG-API.png)

#### d. OKX
请使用 「合约模式】 或 「跨币种保证金模式」，并开启双向持仓
权限相关参考下图：\
![](images/OKX-API.png)

#### e. Gate
 ==> 请开启双向持仓(交易设置->交易配置->持仓模式选择双向持仓)  \
 ==> 请使用 **统一账户 + 跨币种保证金模式**，权限相关参考下图：\
![](images/Gate-API.png)

#### f. Kucoin
==> 请开启双向持仓 \
权限相关参考下图：\
![](images/kucoin-API.png)

#### g. Aster
联合保证金模式 + 双向持仓

#### h. Backpack🎒
https://backpack.exchange/portfolio/settings/api-keys

#### i.Hyperliquid
需要三个数据，主钱包地址，代理钱包地址，代理钱包私钥，请参考下面两张图：\
![image](https://github.com/user-attachments/assets/a8676428-a43d-460c-a183-f544ec0d2196) \
![image](https://github.com/user-attachments/assets/e52b0c84-29ca-4e66-8af3-5ae76840a4b4)

#### j. Htx
==> 请设置资产模式为联合保证金模式（资产模式->联合保证金模式）\
==> 请设置为双向持仓 （持仓模式->双向持仓）
权限相关参考下图：\
![](images/htx1.png) \
![](images/htx2.png)

#### k. Lighter
1. 切勿勾选「仅减仓」选项， 否则无法开单 \
API KEY 相关参考下图：\
![](images/lighter1.png) \
![](images/lighter2.png)

