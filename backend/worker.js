/**
 * Welcome to Cloudflare Workers!
 *
 * This is a template for a Worker which exposes a HTTP API for
 * verifying redemption codes stored in Cloudflare KV.
 *
 * KV Namespace Binding: PAPER_WHISPER_CODES
 */

export default {
    async fetch(request, env, ctx) {
        // Handle CORS
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

        const url = new URL(request.url);

        // Route: /redeem
        if (url.pathname === "/redeem") {
            return await handleRedeem(request, env);
        }

        return new Response("Not Found", { status: 404 });
    },
};

async function handleRedeem(request, env) {
    try {
        const body = await request.json();
        const code = body.code ? body.code.trim().toUpperCase() : "";
        const deviceId = body.deviceId || "unknown_device";

        if (!code) {
            return jsonResponse({ success: false, message: "Invalid code format" }, 400);
        }

        // 1. Fetch code data from KV
        // Key format: RC_<CODE> (e.g., RC_PW-A1B2-C3D4-E5F6)
        const key = `RC_${code}`;
        const dataStr = await env.PAPER_WHISPER_CODES.get(key);

        if (!dataStr) {
            // Anti-brute-force delay
            await new Promise(r => setTimeout(r, 1000));
            return jsonResponse({ success: false, message: "Invalid or expired code" }, 400);
        }

        let data;
        try {
            data = JSON.parse(dataStr);
        } catch (e) {
            return jsonResponse({ success: false, message: "Data corruption error" }, 500);
        }

        // 2. Check logic
        // Initialize devices array if not present
        if (!data.devices) data.devices = [];
        if (!data.usage) data.usage = 0;
        if (!data.limit) data.limit = 5; // Default limit 5

        // If this device already redeemed it, just return success (idempotency)
        if (data.devices.includes(deviceId)) {
            return jsonResponse({
                success: true,
                message: "Already activated on this device",
                type: data.type || "lifetime"
            });
        }

        // Check limits
        if (data.usage >= data.limit) {
            return jsonResponse({ success: false, message: "Activation limit reached" }, 403);
        }

        // 3. Update State
        data.usage += 1;
        data.devices.push(deviceId);
        data.last_redeemed_at = Date.now();

        // Write back to KV
        await env.PAPER_WHISPER_CODES.put(key, JSON.stringify(data));

        return jsonResponse({
            success: true,
            message: "Activation successful",
            type: data.type || "lifetime"
        });

    } catch (e) {
        return jsonResponse({ success: false, message: e.message }, 500);
    }
}

function jsonResponse(data, status = 200) {
    return new Response(JSON.stringify(data), {
        status: status,
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
        },
    });
}
