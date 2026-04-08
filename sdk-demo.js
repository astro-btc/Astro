const crypto = require('crypto')
const http = require('http');
const https = require('https');

const ACTIONS_WITH_PAIR = new Set(['add', 'update', 'delete'])
const MESSAGE_TYPES = new Set(['warning', 'notice'])

function generateNonce() {
    return crypto.randomBytes(24).toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=/g, '')
        .slice(0, 32);
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

const buildSimplePayload = (action, pair) => {
    const payload = { action }
    if (ACTIONS_WITH_PAIR.has(action)) {
        payload.pair = pair
    }
    return payload
}

const buildMessagePayload = (type, text) => {
    return {
        type,
        text
    }
}

const buildCanonicalMessage = ({ method = 'POST', path = '', nonce, ts, rawBody = '' }) => {
    return [
        String(ts),
        String(nonce),
        String(method).toUpperCase(),
        String(path),
        typeof rawBody === 'string' ? rawBody : ''
    ].join('\n')
}

const simpleSignRawBody = (key, nonce, ts, path, rawBody, method = 'POST') => {
    const signContent = buildCanonicalMessage({ method, path, nonce, ts, rawBody })
    return crypto.createHmac('sha256', String(key))
        .update(signContent)
        .digest('hex');
}

// ============ 配置 ============
// API Key - 需要先在账户->开发者代码通过「set api-key ***」设置API KEY, 随机数长度12-32，数字和大小写字母
// ⚠️ 如果api key被黑客盗取，黑客就可以开单了，切记谨慎保管，定期更换，长度尽量长
const API_KEY = process.env.ASTRO_API_KEY || '***'; // 请替换为实际的 API Key

// 服务器地址
const BASE_URL = '127.0.0.1'; // 请替换为实际的服务器地址
const PORT = 8443;
const PAIR_API_PATH = '/api/config/sdk-update-pair';
const MESSAGE_API_PATH = '/api/config/sdk-send-message';

// 默认使用 HTTPS
const USE_HTTPS = true;
const PROTOCOL = USE_HTTPS ? 'https' : 'http';
const HTTP_MODULE = USE_HTTPS ? https : http;

// 忽略 SSL 证书验证
if (USE_HTTPS) {
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
}

// ============ Pair 模板 ============
const pair = {
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
    "maxNotional": "30",
};

const messageDemoPayload = {
    warning: '「测试」⚠️ASTRO SDK API报警消息',
    notice: '「测试」ASTRO SDK API通知消息'
}

function createUpdatedPair(addedPair) {
    return {
        ...addedPair,
        status: true,
        disableOpen: true,
        maxTradeUSDT: '1200',
        minNotional: '15',
        maxNotional: '40',
        openPosition: '0.0188',
        closePosition: '0.0033'
    };
}

function printDivider(title) {
    console.log('\n' + '='.repeat(28));
    console.log(title);
    console.log('='.repeat(28));
}

function printJson(title, value) {
    console.log(title);
    console.log(JSON.stringify(value, null, 2));
}

function summarizePair(targetPair) {
    if (!targetPair) {
        return null
    }
    return {
        id: targetPair.id,
        name: targetPair.name,
        type: targetPair.type,
        status: targetPair.status,
        disableOpen: targetPair.disableOpen,
        openPosition: targetPair.openPosition,
        closePosition: targetPair.closePosition,
        maxTradeUSDT: targetPair.maxTradeUSDT,
        minNotional: targetPair.minNotional,
        maxNotional: targetPair.maxNotional,
        buyEx: targetPair.buyEx,
        sellEx: targetPair.sellEx
    }
}

function assertSuccess(stepName, response) {
    if (response.statusCode !== 200 || response.json?.code !== 0) {
        throw new Error(`${stepName} 失败，HTTP=${response.statusCode}，响应=${response.rawBody}`);
    }
}

function findPairByName(list, name) {
    return Array.isArray(list) ? list.find(item => item?.name === name) : null
}

function findPairById(list, id) {
    return Array.isArray(list) ? list.find(item => item?.id === id) : null
}

function buildLogSafeHeaders(headers) {
    return {
        'Content-Type': headers['Content-Type'],
        'x-timestamp': headers['x-timestamp'],
        'Content-Length': headers['Content-Length']
    }
}

function sendSignedRequest(apiPath, payload, stepLabel, summary = {}) {
    const timestamp = Date.now();
    const nonce = generateNonce();
    const requestBody = JSON.stringify(payload);
    const sign = simpleSignRawBody(API_KEY, nonce, timestamp, apiPath, requestBody, 'POST');

    const headers = {
        'Content-Type': 'application/json',
        'x-timestamp': timestamp.toString(),
        'x-sign': sign,
        'x-nonce': nonce,
        'Content-Length': Buffer.byteLength(requestBody)
    };

    const options = {
        hostname: BASE_URL,
        port: PORT,
        path: apiPath,
        method: 'POST',
        headers
    };

    printDivider(`[${stepLabel}] 请求开始`);
    console.log('Protocol:', PROTOCOL.toUpperCase());
    console.log('URL:', `${PROTOCOL}://${BASE_URL}:${PORT}${apiPath}`);
    if (summary.action) {
        console.log('Action:', summary.action);
    }
    if (summary.type) {
        console.log('Type:', summary.type);
    }
    console.log('Timestamp:', timestamp);
    printJson('Headers:', buildLogSafeHeaders(headers));
    printJson('Body:', payload);

    return new Promise((resolve, reject) => {
        const req = HTTP_MODULE.request(options, (res) => {
            let data = '';

            res.on('data', (chunk) => {
                data += chunk;
            });

            res.on('end', () => {
                let json = null
                try {
                    json = JSON.parse(data);
                } catch (e) {
                }

                printDivider(`[${stepLabel}] 响应完成`);
                console.log('Status Code:', res.statusCode);
                console.log('Status Message:', res.statusMessage);
                printJson('Response Headers:', res.headers);
                if (json) {
                    printJson('Response JSON:', json);
                } else {
                    console.log('Response Body (raw):');
                    console.log(data);
                }

                resolve({
                    statusCode: res.statusCode,
                    statusMessage: res.statusMessage,
                    headers: res.headers,
                    json,
                    rawBody: data
                });
            });
        });

        req.on('error', (error) => {
            printDivider(`[${stepLabel}] 请求错误`);
            console.error('Error:', error.message);
            if (error.code === 'ECONNREFUSED') {
                console.error('提示: 无法连接到服务器，请确保服务器正在运行');
            } else if (USE_HTTPS && (error.code === 'CERT_HAS_EXPIRED' || error.code === 'UNABLE_TO_VERIFY_LEAF_SIGNATURE')) {
                console.error('提示: SSL 证书验证失败，已设置忽略证书验证');
            }
            reject(error);
        });

        req.write(requestBody);
        req.end();
    });
}

function sendRequest(action, pairData, stepLabel) {
    const payload = buildSimplePayload(action, pairData);
    return sendSignedRequest(PAIR_API_PATH, payload, stepLabel, { action })
}

function sendMessageRequest(type, text, stepLabel) {
    if (!MESSAGE_TYPES.has(type)) {
        throw new Error(`无效的消息类型: ${type}`);
    }
    if (typeof text !== 'string' || !text.trim()) {
        throw new Error('text 必须是非空字符串');
    }

    const payload = buildMessagePayload(type, text);
    return sendSignedRequest(MESSAGE_API_PATH, payload, stepLabel, { type })
}

async function runDemoFlow() {
    printDivider('Pair Demo Flow 启动');
    console.log(`目标接口: ${PROTOCOL}://${BASE_URL}:${PORT}${PAIR_API_PATH}`);

    printJson('Add Pair 模板:', summarizePair(pair));

    const listBefore = await sendRequest('list', null, 'Step 1 - list');
    assertSuccess('Step 1 - list', listBefore);
    const beforeList = listBefore.json?.data || [];
    console.log('Step 1 结果: 当前总 pair 数量 =', beforeList.length);
    const beforeExisting = findPairByName(beforeList, pair.name);
    if (beforeExisting) {
        throw new Error(`开始前已存在同名 pair，请稍后重试或修改名称: ${pair.name}`);
    }

    const addResult = await sendRequest('add', pair, 'Step 2 - add');
    assertSuccess('Step 2 - add', addResult);
    console.log('Step 2 结果: add 请求已提交成功');

    // 新增pair会导致astro-core进程重启，因此此动作完成后需要等待3秒再执行其他动作。
    await sleep(4000);

    const listAfterAdd = await sendRequest('list', null, 'Step 3 - list');
    assertSuccess('Step 3 - list', listAfterAdd);
    const afterAddList = listAfterAdd.json?.data || [];
    console.log('Step 3 结果: 当前总 pair 数量 =', afterAddList.length);
    const addedPair = findPairByName(afterAddList, pair.name);
    if (!addedPair) {
        throw new Error('Step 3 - list 未找到刚刚新增的 pair，无法继续 update/delete 流程');
    }
    printJson('Step 3 找到新增 pair:', summarizePair(addedPair));

    const pairForUpdate = createUpdatedPair(addedPair);
    printJson('Step 4 将要更新为:', summarizePair(pairForUpdate));
    const updateResult = await sendRequest('update', pairForUpdate, 'Step 4 - updatePair');
    assertSuccess('Step 4 - updatePair', updateResult);
    console.log('Step 4 结果: update 请求已提交成功');

    const listAfterUpdate = await sendRequest('list', null, 'Step 5 - list');
    assertSuccess('Step 5 - list', listAfterUpdate);
    const afterUpdateList = listAfterUpdate.json?.data || [];
    const updatedPair = findPairById(afterUpdateList, addedPair.id);
    if (!updatedPair) {
        throw new Error(`Step 5 - list 未找到 id=${addedPair.id} 的 pair`);
    }
    printJson('Step 5 更新后的 pair:', summarizePair(updatedPair));

    const deletePayload = { id: addedPair.id };
    printJson('Step 6 删除参数:', deletePayload);
    const deleteResult = await sendRequest('delete', deletePayload, 'Step 6 - delete');
    assertSuccess('Step 6 - delete', deleteResult);
    console.log('Step 6 结果: delete 请求已提交成功');

    const listAfterDelete = await sendRequest('list', null, 'Step 7 - list');
    assertSuccess('Step 7 - list', listAfterDelete);
    const afterDeleteList = listAfterDelete.json?.data || [];
    const deletedPair = findPairById(afterDeleteList, addedPair.id);
    console.log('Step 7 结果: 当前总 pair 数量 =', afterDeleteList.length);
    if (deletedPair) {
        throw new Error(`Step 7 - list 发现 pair 仍然存在，删除未生效: ${addedPair.id}`);
    }
    console.log('Step 7 校验成功: 已确认目标 pair 不在列表中');

    printDivider('Pair Demo Flow 完成');
    console.log('完整流程执行成功: list -> add -> list -> updatePair -> list -> delete -> list');
    console.log('本次演示 pair id:', addedPair.id);
    console.log('本次演示 pair name:', addedPair.name);
}

async function runMessageDemoFlow() {
    printDivider('Message Demo Flow 启动');
    console.log(`目标接口: ${PROTOCOL}://${BASE_URL}:${PORT}${MESSAGE_API_PATH}`);

    const warningText = messageDemoPayload.warning
    printJson('Message Step 1 请求体:', buildMessagePayload('warning', warningText));
    const warningResult = await sendMessageRequest('warning', warningText, 'Message Step 1 - warning');
    assertSuccess('Message Step 1 - warning', warningResult);
    console.log('Message Step 1 结果: warning 文本已提交成功');

    const noticeText = messageDemoPayload.notice
    printJson('Message Step 2 请求体:', buildMessagePayload('notice', noticeText));
    const noticeResult = await sendMessageRequest('notice', noticeText, 'Message Step 2 - notice');
    assertSuccess('Message Step 2 - notice', noticeResult);
    console.log('Message Step 2 结果: notice 文本已提交成功');

    printDivider('Message Demo Flow 完成');
    console.log('完整流程执行成功: warning -> notice');
}

async function runAllDemos() {
    await runDemoFlow();
    await runMessageDemoFlow();
}

if (require.main === module) {
    runAllDemos().catch((error) => {
        printDivider('Demo Flow 失败');
        console.error(error?.stack || error?.message || error);
        process.exitCode = 1;
    });
}

module.exports = {
    sendRequest,
    sendMessageRequest,
    runDemoFlow,
    runMessageDemoFlow,
    runAllDemos,
    generateNonce,
    pair,
    buildSimplePayload,
    buildMessagePayload
};
