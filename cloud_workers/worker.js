/**
 * Cloudflare Worker for PaperWhisper Premium Activation
 * 
 * 环境变量 (需要在 CF 后台设置):
 * - AFDIAN_USER_ID: 爱发电 User ID
 * - AFDIAN_TOKEN: 爱发电 Token
 * - APP_SECRET: 用于签名激活 Token 的密钥 (和 App 端保持一致)
 * - ORDER_KV: KV 命名空间绑定名称 (例如 "PAPERWHISPER_ORDERS")
 */

export default {
    async fetch(request, env, ctx) {
        // 1. CORS 处理 (允许跨域)
        if (request.method === "OPTIONS") {
            return new Response(null, {
                headers: {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "POST, OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type",
                },
            });
        }

        if (request.method !== "POST") {
            return new Response("Method Not Allowed", { status: 405 });
        }

        try {
            const { order_id } = await request.json();

            if (!order_id) {
                return jsonResponse({ error: "Missing order_id" }, 400);
            }

            // 2. 检查 KV 中的激活次数
            // Key: order_{order_id}, Value: count (int)
            const kvKey = `order_${order_id}`;
            const currentCountStr = await env.ORDER_KV.get(kvKey);
            let currentCount = currentCountStr ? parseInt(currentCountStr) : 0;

            const MAX_ACTIVATIONS = 5;

            if (currentCount >= MAX_ACTIVATIONS) {
                return jsonResponse({
                    success: false,
                    message: "激活次数已达上限 (5/5)。请联系开发者重置。",
                    code: "LIMIT_EXCEEDED"
                }, 403);
            }

            // 3. 调用爱发电 API 验证订单有效性
            // 如果 KV 里没有记录 (第一次激活)，或者虽然通过了 KV 检查但为了保险起见，
            // 我们还是应该去爱发电查一下这个订单是否真的存在且已支付。
            // (为了性能，也可以选择只在 count=0 时查 API，后续直接信 KV。但为了防止退款后还能激活，建议每次都查，或者缓存查单结果)

            const isValidOrder = await verifyAfdianOrder(order_id, env);

            if (!isValidOrder) {
                return jsonResponse({
                    success: false,
                    message: "无效的订单号或未支付",
                    code: "INVALID_ORDER"
                }, 400);
            }

            // 4. 更新激活次数
            const newCount = currentCount + 1;
            await env.ORDER_KV.put(kvKey, newCount.toString());

            // 5. 生成签名 Token (JWT)
            // Payload 包含: order_id, timestamp, is_pro: true
            const token = await signToken({
                oid: order_id,
                ts: Date.now(),
                pro: true
            }, env.APP_SECRET);

            return jsonResponse({
                success: true,
                data: {
                    token: token,
                    activations: newCount,
                    max_activations: MAX_ACTIVATIONS
                }
            });

        } catch (e) {
            return jsonResponse({ error: e.message }, 500);
        }
    },
};

// --- Helpers ---

function jsonResponse(data, status = 200) {
    return new Response(JSON.stringify(data), {
        status: status,
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        }
    });
}

/**
 * 查询爱发电 API 验证订单
 */
async function verifyAfdianOrder(orderId, env) {
    const userId = env.AFDIAN_USER_ID;
    const token = env.AFDIAN_TOKEN;

    if (!userId || !token) throw new Error("Missing Afdian Env Config");

    // 构造请求参数
    const ts = Math.floor(Date.now() / 1000);
    const params = JSON.stringify({ out_trade_no: orderId }); // 使用 out_trade_no 查询

    // 签名逻辑: md5(token + params + ts + userId)
    const signStr = `${token}params${params}ts${ts}user_id${userId}`;
    const sign = await md5(signStr);

    const url = `https://afdian.com/api/open/query-order?user_id=${userId}&params=${encodeURIComponent(params)}&ts=${ts}&sign=${sign}`;

    const resp = await fetch(url);
    const data = await resp.json();

    // 检查 API 返回
    // ec === 200 表示成功
    if (data.ec !== 200) {
        console.error("Afdian API Error:", data.em);
        return false;
    }

    // 检查 list 中是否有匹配的订单
    const list = data.data.list;
    if (!list || list.length === 0) return false;

    // 找到匹配的订单
    // 注意：Afdian 可能会返回多个结果，需要精确匹配 out_trade_no (订单号)
    const order = list.find(item => item.out_trade_no === orderId);

    if (!order) return false;

    // 检查sku是否匹配 (可选，防止用户买错了便宜的一块钱商品来激活)
    // if (order.sku_id !== "YOUR_PRO_SKU_ID") return false; 

    // 简单起见，只要有这个订单且是用该订单号查出来的，就认为是有效的赞助
    return true;
}

/**
 * 简单的 MD5 实现 (CF Worker环境)
 */
async function md5(message) {
    const msgUint8 = new TextEncoder().encode(message);
    const hashBuffer = await crypto.subtle.digest('MD5', msgUint8);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
    return hashHex;
}

/**
 * HS256 签名 (简化版 JWT)
 */
async function signToken(payload, secret) {
    const header = { alg: "HS256", typ: "JWT" };
    const encodedHeader = b64url(JSON.stringify(header));
    const encodedPayload = b64url(JSON.stringify(payload));

    const waitSign = `${encodedHeader}.${encodedPayload}`;

    const key = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
    );

    const signature = await crypto.subtle.sign(
        "HMAC",
        key,
        new TextEncoder().encode(waitSign)
    );

    const encodedSignature = b64url_bytes(signature);

    return `${waitSign}.${encodedSignature}`;
}

function b64url(str) {
    return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64url_bytes(buffer) {
    let binary = '';
    const bytes = new Uint8Array(buffer);
    const len = bytes.byteLength;
    for (let i = 0; i < len; i++) {
        binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
